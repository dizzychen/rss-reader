// AI 服务封装 - 支持通义千问原生 API 和 OpenAI 兼容协议
import { http } from '@kit.NetworkKit';
import { Article } from '../model/Models';
import { Constants } from '../constants/Constants';
import { MemoryService } from './MemoryService';
import { DateUtil } from '../utils/DateUtil';

// ===== 通义千问专用类型 =====

class QwenMessage {
  role: string;
  content: string;

  constructor(role: string, content: string) {
    this.role = role;
    this.content = content;
  }
}

class QwenInput {
  messages: QwenMessage[] = [];
}

class QwenParameters {
  result_format: string = '';
  max_tokens: number = 0;
  temperature: number = 0;
}

class QwenRequest {
  model: string = '';
  input: QwenInput = new QwenInput();
  parameters: QwenParameters = new QwenParameters();
}

// 通义千问 result_format='message' 时的 choice 结构
class QwenChoiceMessage {
  role: string = '';
  content: string = '';
}

class QwenChoice {
  finish_reason: string = '';
  message: QwenChoiceMessage = new QwenChoiceMessage();
}

class QwenOutput {
  text: string = '';              // result_format='text' 时使用
  choices: QwenChoice[] = [];     // result_format='message' 时使用
}

class QwenResponse {
  output: QwenOutput = new QwenOutput();
  request_id: string = '';
  code: string = '';              // 错误时返回
  message: string = '';           // 错误时返回
}

// ===== OpenAI 兼容类型 =====

class OpenAIMessage {
  role: string;
  content: string;

  constructor(role: string, content: string) {
    this.role = role;
    this.content = content;
  }
}

class OpenAIRequest {
  model: string = '';
  messages: OpenAIMessage[] = [];
  max_tokens: number = 0;
  temperature: number = 0;
}

class OpenAIMessage2 {
  role: string = '';
  content: string = '';
}

class OpenAIChoice {
  message: OpenAIMessage2 = new OpenAIMessage2();
}

class OpenAIResponse {
  choices: OpenAIChoice[] = [];
}

export class AIService {
  private static instance: AIService;
  private apiKey: string = '';
  private provider: string = 'qwen';
  private baseUrl: string = '';
  private model: string = '';

  /**
   * 统一错误消息提取：兼容 Error 和 HarmonyOS BusinessError { code, message }
   */
  private static extractErrMsg(e: Object): string {
    if (e instanceof Error) {
      return e.message;
    }
    const be = e as Record<string, Object>;
    const code = be['code'] !== undefined ? String(be['code']) : '';
    const msg  = be['message'] !== undefined ? String(be['message']) : JSON.stringify(e);
    return code.length > 0 ? `[${code}] ${msg}` : msg;
  }

  static getInstance(): AIService {
    if (!AIService.instance) {
      AIService.instance = new AIService();
    }
    return AIService.instance;
  }

  /**
   * 设置 API Key
   */
  setApiKey(key: string): void {
    this.apiKey = key.trim();
  }

  /**
   * 设置 AI 提供商（'qwen' | 'openai' | 'deepseek' | 'groq' | 'custom'）
   */
  setProvider(provider: string): void {
    this.provider = provider;
  }

  /**
   * 设置自定义 Base URL
   */
  setBaseUrl(url: string): void {
    this.baseUrl = url.trim();
  }

  /**
   * 设置模型名称
   */
  setModel(name: string): void {
    this.model = name.trim();
  }

  /**
   * 判断是否已配置 API Key
   */
  hasApiKey(): boolean {
    return this.apiKey.length > 0;
  }

  /**
   * 获取当前提供商
   */
  getProvider(): string {
    return this.provider;
  }

  /**
   * 获取当前 Base URL（用于在 UI 中显示）
   */
  getBaseUrl(): string {
    return this.baseUrl;
  }

  /**
   * 获取当前模型名称（用于在 UI 中显示）
   */
  getModel(): string {
    return this.model;
  }

  /**
   * 统一对话入口，根据 provider 分发到各实现
   */
  async chat(systemPrompt: string, userPrompt: string, maxTokens: number = 1000): Promise<string> {
    if (!this.hasApiKey()) {
      throw new Error('未配置 AI API Key，请在设置中填写 API Key');
    }

    // 如果用户填入了自定义 Base URL，统一使用 OpenAI 兼容协议
    // 因为自定义 URL（如 coding.dashscope.aliyuncs.com/v1）都是 OpenAI 兼容格式
    if (this.baseUrl.length > 0) {
      return this.chatOpenAI(systemPrompt, userPrompt, maxTokens);
    }

    // 无自定义 URL 时，根据 provider 选择协议
    if (this.provider === 'qwen') {
      return this.chatQwen(systemPrompt, userPrompt, maxTokens);
    } else {
      return this.chatOpenAI(systemPrompt, userPrompt, maxTokens);
    }
  }

  /**
   * 通义千问原生 API 调用
   */
  private async chatQwen(systemPrompt: string, userPrompt: string, maxTokens: number): Promise<string> {
    const messages: QwenMessage[] = [];
    messages.push(new QwenMessage('system', systemPrompt));
    messages.push(new QwenMessage('user', userPrompt));

    const input = new QwenInput();
    input.messages = messages;

    const params = new QwenParameters();
    params.result_format = 'message';
    params.max_tokens = maxTokens;
    params.temperature = 0.7;

    const requestBody = new QwenRequest();
    // 优先使用用户配置的模型名，否则用默认值
    requestBody.model = this.model.length > 0 ? this.model : Constants.QWEN_MODEL;
    requestBody.input = input;
    requestBody.parameters = params;

    // 优先使用自定义 Base URL（通义千问兼容场景），否则使用官方地址
    const url = this.baseUrl.length > 0 ? this.baseUrl : Constants.QWEN_API_URL;

    const httpRequest = http.createHttp();
    try {
      console.info('AIService', `chatQwen: url=${url}, model=${requestBody.model}`);
      const response = await httpRequest.request(
        url,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.apiKey}`
          },
          extraData: JSON.stringify(requestBody),
          connectTimeout: 15000,
          readTimeout: 60000
        }
      );

      // 先检查 HTTP 状态码
      if (response.responseCode !== 200) {
        // 尝试解析错误响应
        let errMsg = `HTTP ${response.responseCode}`;
        try {
          const errResult = JSON.parse(response.result as string) as QwenResponse;
          if (errResult.message) {
            errMsg = `${errResult.code || ''} ${errResult.message}`;
          }
        } catch {
          // 响应不是 JSON，使用原始错误码
        }
        throw new Error(`API 错误: ${errMsg}`);
      }

      const result = JSON.parse(response.result as string) as QwenResponse;

      // 兼容两种响应格式：
      // 1. result_format='text' 时，返回 output.text
      // 2. result_format='message' 时，返回 output.choices[0].message.content
      if (result.output?.choices && result.output.choices.length > 0) {
        return result.output.choices[0].message.content || '';
      }
      return result.output?.text ?? '';
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * OpenAI 兼容协议调用（适用于 OpenAI、DeepSeek、Groq、自定义等）
   */
  private async chatOpenAI(systemPrompt: string, userPrompt: string, maxTokens: number): Promise<string> {
    const apiUrl = this.resolveOpenAIUrl();
    if (apiUrl.length === 0) {
      throw new Error('未配置 API 端点，请在设置中填写 Base URL');
    }

    const modelName = this.resolveModelName();
    if (modelName.length === 0) {
      throw new Error('未配置模型名称，请在设置中填写模型名称');
    }

    const messages: OpenAIMessage[] = [];
    messages.push(new OpenAIMessage('system', systemPrompt));
    messages.push(new OpenAIMessage('user', userPrompt));

    const requestBody = new OpenAIRequest();
    requestBody.model = modelName;
    requestBody.messages = messages;
    requestBody.max_tokens = maxTokens;
    requestBody.temperature = 0.7;

    const httpRequest = http.createHttp();
    try {
      console.info('AIService', `chatOpenAI: url=${apiUrl}, model=${modelName}, timeout=60s`);
      const response = await httpRequest.request(
        apiUrl,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.apiKey}`
          },
          extraData: JSON.stringify(requestBody),
          connectTimeout: 15000,
          readTimeout: 60000
        }
      );

      // 先检查 HTTP 状态码
      if (response.responseCode !== 200) {
        let errMsg = `HTTP ${response.responseCode}`;
        try {
          const errResult = JSON.parse(response.result as string) as Record<string, Object>;
          const errObj = errResult['error'] as Record<string, string> | undefined;
          if (errObj && errObj['message']) {
            errMsg = errObj['message'];
          }
        } catch {
          // 响应不是 JSON
        }
        throw new Error(`API 错误: ${errMsg}`);
      }

      let result: OpenAIResponse;
      try {
        result = JSON.parse(response.result as string) as OpenAIResponse;
      } catch (parseErr) {
        const parseMsg = AIService.extractErrMsg(parseErr);
        throw new Error(`JSON 解析失败: ${parseMsg}，响应: ${String(response.result).substring(0, 200)}`);
      }
      if (result.choices.length === 0) {
        return '';
      }
      return result.choices[0].message.content;
    } catch (e) {
      const errMsg = AIService.extractErrMsg(e);
      console.error('AIService', `chatOpenAI failed: ${errMsg}`);
      throw new Error(errMsg);
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * 解析 OpenAI 兼容接口的完整 URL
   * 优先使用用户设置的 baseUrl，否则按 provider 查预设
   */
  private resolveOpenAIUrl(): string {
    /**
     * 统一处理逻辑：将 Base URL 规范化为完整的 chat/completions 端点
     * 兼容两种格式：
     *   - 已含 /v1 结尾：直接追加 /chat/completions
     *   - 不含 /v1：追加 /v1/chat/completions
     *   - 已含完整路径 /chat/completions：原样返回
     */
    const normalizeToEndpoint = (base: string): string => {
      const b = base.replace(/\/$/, '');
      if (b.endsWith('/chat/completions')) {
        return b;
      }
      if (b.endsWith('/v1')) {
        return `${b}/chat/completions`;
      }
      return `${b}/v1/chat/completions`;
    };

    if (this.baseUrl.length > 0) {
      return normalizeToEndpoint(this.baseUrl);
    }
    // 按 provider 查预设 Base URL
    const idx = Constants.AI_PROVIDER_KEYS.indexOf(this.provider);
    if (idx >= 0 && idx < Constants.AI_PROVIDER_URLS.length) {
      const presetBase = Constants.AI_PROVIDER_URLS[idx];
      if (presetBase.length > 0) {
        return normalizeToEndpoint(presetBase);
      }
    }
    return '';
  }

  /**
   * 解析最终使用的模型名称
   * 优先使用用户配置的 model，否则按 provider 查预设默认值
   */
  private resolveModelName(): string {
    if (this.model.length > 0) {
      return this.model;
    }
    const idx = Constants.AI_PROVIDER_KEYS.indexOf(this.provider);
    if (idx >= 0 && idx < Constants.AI_PROVIDER_DEFAULT_MODELS.length) {
      return Constants.AI_PROVIDER_DEFAULT_MODELS[idx];
    }
    return '';
  }

  /**
   * 文章智能排序
   */
  async rankArticles(articles: Article[]): Promise<number[]> {
    if (!this.hasApiKey() || articles.length === 0) {
      return [];
    }

    // 检查缓存
    const cached = MemoryService.getInstance().getAIRankCache();
    if (cached !== null && cached.length > 0) {
      // 过滤出当前文章列表中存在的 ID
      const currentIds = new Set<number>();
      for (const a of articles) {
        if (a.id !== undefined) {
          currentIds.add(a.id);
        }
      }
      const validCached: number[] = [];
      for (const id of cached) {
        if (currentIds.has(id)) {
          validCached.push(id);
        }
      }
      if (validCached.length > 0) {
        return validCached;
      }
    }

    try {
      const context = await MemoryService.getInstance().buildAIContext();

      // 构建文章列表摘要（避免上下文过长，限制前30篇）
      let articleSummaries = '';
      const maxArticles = Math.min(30, articles.length);
      for (let i = 0; i < maxArticles; i++) {
        const a = articles[i];
        articleSummaries += `${i + 1}. [ID:${a.id}] ${a.title} (来源:${a.feedTitle ?? '未知'})\n`;
      }

      const systemPrompt = context
        ? `你是一个智能RSS阅读助手，了解用户的阅读偏好。\n\n${context}`
        : '你是一个智能RSS阅读助手。';

      const userPrompt = `请根据我的阅读偏好，对以下文章按推荐度排序。
只输出排序后的文章序号（如：5,2,1,3,4），不要解释。

文章列表：
${articleSummaries}`;

      const response = await this.chat(systemPrompt, userPrompt, 200);

      // 解析 AI 返回的序号列表
      const rankedIds = this.parseRankResponse(response, articles);

      if (rankedIds.length > 0) {
        MemoryService.getInstance().setAIRankCache(rankedIds);
      }

      return rankedIds;
    } catch (e) {
      const msg = AIService.extractErrMsg(e);
      console.error('AIService', `rankArticles failed: ${msg}`);
      return [];
    }
  }

  /**
   * 解析 AI 排序响应，提取 articleId 数组
   */
  private parseRankResponse(response: string, articles: Article[]): number[] {
    try {
      // 提取数字序列（如 "5,2,1,3,4" 或 "5、2、1、3、4"）
      const matches = response.match(/[\d,，、\s]+/);
      if (!matches) {
        return [];
      }
      const indices: number[] = [];
      const parts = matches[0].split(/[,，、\s]+/);
      for (const part of parts) {
        const trimmed = part.trim();
        if (trimmed.length > 0) {
          const idx = parseInt(trimmed, 10) - 1;  // 转为 0-based 索引
          if (idx >= 0 && idx < articles.length) {
            indices.push(idx);
          }
        }
      }

      const result: number[] = [];
      for (const i of indices) {
        const id = articles[i].id;
        if (id !== undefined && id !== -1) {
          result.push(id);
        }
      }
      return result;
    } catch {
      return [];
    }
  }

  /**
   * 生成每日简报
   */
  async generateBriefing(articles: Article[]): Promise<string> {
    if (!this.hasApiKey() || articles.length === 0) {
      return '暂无数据可生成简报';
    }

    try {
      const context = await MemoryService.getInstance().buildAIContext();
      const today = DateUtil.today();

      let articleList = '';
      const maxArticles = Math.min(50, articles.length);
      for (let i = 0; i < maxArticles; i++) {
        const a = articles[i];
        const summary = (a.summary || '').substring(0, 100);
        articleList += `${i + 1}. **${a.title}**\n   来源：${a.feedTitle ?? '未知'}\n   摘要：${summary}\n\n`;
      }

      const systemPrompt = context
        ? `你是我的私人阅读助手，了解我的阅读偏好。\n\n${context}`
        : '你是一个智能阅读助手。';

      const userPrompt = `今天是 ${today}，请从以下文章中为我筛选出 3-5 篇最值得阅读的内容，生成一份简洁的每日简报。

格式要求：
- 直接输出纯文本，不要使用任何 Markdown 语法（不要使用 **、#、- 等符号）
- 开头用一句话概括今日资讯主题（20字以内）
- 每条新闻格式：序号、标题、一句话概述（30字内）、来源
- 条目之间空一行
- 结尾一句今日阅读建议

示例格式：
今日聚焦：科技与商业

1. 苹果发布新款 MacBook Pro
搭载 M4 芯片，性能大幅提升，续航达 24 小时。
来源：36氪

2. 特斯拉股价创新高
受益于自动驾驶技术突破，市值突破万亿美元。
来源：华尔街日报

今日建议：关注科技巨头动态，把握行业趋势。

今日文章（共${articles.length}篇）：
${articleList}`;

      return await this.chat(systemPrompt, userPrompt, 800);
    } catch (e) {
      const msg = AIService.extractErrMsg(e);
      console.error('AIService', `generateBriefing failed: ${msg}`);
      throw new Error(`generateBriefing failed: ${msg}`);
    }
  }

  /**
   * 精读辅助分析
   */
  async analyzeArticle(article: Article): Promise<string> {
    if (!this.hasApiKey()) {
      throw new Error('未配置 AI API Key');
    }

    try {
      const context = await MemoryService.getInstance().buildAIContext();

      const content = (article.content || article.summary || '').substring(0, 2000);

      const systemPrompt = context
        ? `你是我的私人阅读助手，了解我的阅读偏好。\n\n${context}`
        : '你是一个智能阅读助手。';

      const userPrompt = `请对以下文章进行解读：

标题：${article.title}
来源：${article.feedTitle ?? '未知'}
内容：${content}

请提供：
1. **文章总结**（100字以内概括全文）
2. **核心观点**（2-3条要点）`;

      return await this.chat(systemPrompt, userPrompt, 400);
    } catch (e) {
      const msg = AIService.extractErrMsg(e);
      console.error('AIService', `analyzeArticle failed: ${msg}`);
      throw new Error(`analyzeArticle failed: ${msg}`);
    }
  }
}
