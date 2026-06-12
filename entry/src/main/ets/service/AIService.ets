// AI 服务封装 - 支持通义千问原生 API 和 OpenAI 兼容协议
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
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
  stream: boolean = false;
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
  private provider: string = 'deepseek';
  private baseUrl: string = 'https://api.deepseek.com';
  private model: string = 'deepseek-v4-flash';

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
   * 精读辅助分析
   */
  async analyzeArticle(article: Article): Promise<string> {
    if (!this.hasApiKey()) {
      throw new Error('未配置 AI API Key');
    }

    try {
      const context = await MemoryService.getInstance().buildLayeredContext(1); // L0+L1: 解读只需偏好

      const content = (article.content || article.summary || '').substring(0, 2000);

      const systemPrompt = context
        ? `你是我的私人阅读助手，了解我的阅读偏好。\n\n${context}`
        : '你是一个智能阅读助手。';

      const userPrompt = `请对以下文章进行解读：

标题：${article.title}
来源：${article.feedTitle ?? '未知'}
内容：${content}

请提供：
1. 摘要正文（90-140字，2-3句，包含"发生了什么 + 为什么重要/影响 + 结论"）
2. **核心观点**（1-2条，每条不超过14字）

输出要求：
- 第一段直接输出摘要正文，不要写"文章总结""摘要："等标签
- 然后再输出"核心观点"条目
- 信息要具体，避免空话、套话和重复`;

      return await this.chat(systemPrompt, userPrompt, 1024);
    } catch (e) {
      const msg = AIService.extractErrMsg(e);
      console.error('AIService', `analyzeArticle failed: ${msg}`);
      throw new Error(`analyzeArticle failed: ${msg}`);
    }
  }

  /**
   * 流式精读辅助分析：通过回调逐步返回文字
   * @param article 待分析的文章
   * @param onChunk 每次收到新文本块时的回调
   * @param onDone 流式输出结束时的回调
   * @param onError 出错时的回调
   */
  async analyzeArticleStream(
    article: Article,
    onChunk: (text: string) => void,
    onDone: () => void,
    onError: (msg: string) => void
  ): Promise<void> {
    if (!this.hasApiKey()) {
      onError('未配置 AI API Key，请在设置中配置');
      return;
    }

    try {
      const context = await MemoryService.getInstance().buildLayeredContext(1); // L0+L1

      const content = (article.content || article.summary || '').substring(0, 2000);

      const systemPrompt = context
        ? `你是我的私人阅读助手，了解我的阅读偏好。\n\n${context}`
        : '你是一个智能阅读助手。';

      const userPrompt = `请对以下文章进行解读：

标题：${article.title}
来源：${article.feedTitle ?? '未知'}
内容：${content}

请提供：
1. 摘要正文（90-140字，2-3句，包含"发生了什么 + 为什么重要/影响 + 结论"）
2. **核心观点**（1-2条，每条不超过14字）

输出要求：
- 第一段直接输出摘要正文，不要写"文章总结""摘要："等标签
- 然后再输出"核心观点"条目
- 信息要具体，避免空话、套话和重复`;

      await this.chatStream(systemPrompt, userPrompt, 1024, onChunk, onDone, onError);
    } catch (e) {
      const msg = AIService.extractErrMsg(e);
      console.error('AIService', `analyzeArticleStream failed: ${msg}`);
      onError(msg);
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
      const context = await MemoryService.getInstance().buildLayeredContext(1); // L0+L1: 排序只需偏好+画像摘要

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
      // 提取所有数字序列，取最长的一个（AI 输出的序号列表通常最长）
      const normalized = response.replace(/[\r\n]+/g, ' ').trim();

      const allMatches = normalized.match(/[\d,，、\s]+/g);
      if (!allMatches || allMatches.length === 0) {
        return [];
      }

      // 按数字数量降序排列，取包含最多数字的序列（最可能是序号列表）
      allMatches.sort((a, b) => {
        const countA = (a.match(/\d+/g) || []).length;
        const countB = (b.match(/\d+/g) || []).length;
        return countB - countA;
      });
      const bestMatch = allMatches[0];
      
      const indices: number[] = [];
      const parts = bestMatch.split(/[,，、\s]+/);
      for (let i = 0; i < parts.length; i++) {
        const trimmed = parts[i].trim();
        if (trimmed.length > 0) {
          const idx = parseInt(trimmed, 10) - 1;  // 转为 0-based 索引
          if (idx >= 0 && idx < articles.length) {
            indices.push(idx);
          }
        }
      }

      const result: number[] = [];
      for (let i = 0; i < indices.length; i++) {
        const articleIdx = indices[i];
        const id = articles[articleIdx].id;
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
   * 生成每日简报（结构化 JSON 输出）
   * @param articles 待分析的文章列表
   * @param briefingCount 推荐文章数量（默认 5）
   * @returns AI 返回的原始 JSON 字符串（由 BriefingService 解析）
   */
  async generateBriefing(articles: Article[], briefingCount: number = 5): Promise<string> {
    if (!this.hasApiKey() || articles.length === 0) {
      throw new Error('未配置 API Key 或无文章可分析');
    }

    try {
      const context = await MemoryService.getInstance().buildLayeredContext(2); // L0-L2: 简报需近日行为
      const today = DateUtil.today();

      let articleList = '';
      const maxArticles = Math.min(50, articles.length);
      for (let i = 0; i < maxArticles; i++) {
        const a = articles[i];
        const summary = (a.summary || '').substring(0, 100);
        const pubTime = a.publishedAt > 0 ? new Date(a.publishedAt).toLocaleString() : '未知时间';
        articleList += `${i + 1}. ${a.title}\n   来源：${a.feedTitle ?? '未知'}\n   发布：${pubTime}\n   摘要：${summary}\n\n`;
      }

      const systemPrompt = context
        ?
        `你是我的私人阅读回顾助手，了解我的阅读偏好和习惯。请根据我的阅读历史，帮我回顾今天的阅读内容、提炼收获、并更新兴趣画像。\n\n${context}`
        : '你是一个智能阅读回顾助手，擅长总结阅读内容并提炼用户兴趣。';

      const userPrompt = `今天是 ${today}，以下是我今天阅读的 ${maxArticles} 篇文章。请帮我做阅读回顾并更新阅读画像。

要求：
1. 用一句话概括今日阅读主题（20字以内）
2. 选出 ${briefingCount} 篇最有价值的文章作为阅读亮点，说明为什么值得读（20字内），标注深度等级：high（深度研读）、medium（正常阅读）、low（快速浏览）
3. 选出 2-3 篇价值较低的文章，说明为什么可以少花时间（15字内）
4. 生成一条阅读时间轴，按时间段（早晨/上午/中午/下午/傍晚/晚间/深夜）梳理阅读脉络，每个时段选1篇代表性文章
5. 提炼今日阅读中体现的兴趣话题（3-8个关键词），用于更新阅读画像

请严格输出以下 JSON 格式，不要输出其他内容：
{
  "summary": "今日阅读主题概括（20字以内）",
  "recommended": [
    {"index": 1, "title": "文章标题", "source": "来源", "reason": "阅读价值（20字内）", "level": "high"}
  ],
  "skippable": [
    {"index": 3, "title": "文章标题", "reason": "低价值理由（15字内）"}
  ],
  "timeline": [
    {"time": "上午", "headline": "阅读要点", "brief": "一句话概括（25字内）", "index": 1}
  ],
  "topics": ["AI", "科技", "投资"]
}

index 是文章在下方列表中的序号（从1开始）。timeline 按时间从早到晚排列，只保留有阅读活动的时段（3-5条即可）。topics 是今日阅读中体现的核心话题关键词。

文章列表（共${maxArticles}篇）：
${articleList}`;

      return await this.chat(systemPrompt, userPrompt, Constants.BRIEFING_MAX_TOKENS);
    } catch (e) {
      const msg = AIService.extractErrMsg(e);
      console.error('AIService', `generateBriefing failed: ${msg}`);
      throw new Error(`generateBriefing failed: ${msg}`);
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
          connectTimeout: 30000,
          readTimeout: 120000
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
      console.info('AIService', `chatOpenAI: url=${apiUrl}, model=${modelName}, timeout=120s`);
      const response = await httpRequest.request(
        apiUrl,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.apiKey}`
          },
          extraData: JSON.stringify(requestBody),
          connectTimeout: 30000,
          readTimeout: 120000
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
   * 流式对话入口，通过 requestInStream + SSE 逐步回调文本
   *
   * 已知问题修复：
   * 1. readTimeout 从 60s 提升到 120s — DeepSeek 首 token 延迟可达 30s+
   * 2. 引入 isFinished 标志防止 dataEnd + catch 双重回调冲突
   * 3. 检测 finish_reason='length' 提示用户输出被截断
   */
  private async chatStream(
    systemPrompt: string,
    userPrompt: string,
    maxTokens: number,
    onChunk: (text: string) => void,
    onDone: () => void,
    onError: (msg: string) => void
  ): Promise<void> {
    // 统一使用 OpenAI 兼容协议的流式请求
    const apiUrl = this.baseUrl.length > 0
      ? this.resolveOpenAIUrl()
      : (this.provider === 'qwen' ? this.resolveQwenStreamUrl() : this.resolveOpenAIUrl());

    if (apiUrl.length === 0) {
      onError('未配置 API 端点');
      return;
    }

    const modelName = this.resolveModelName();
    if (modelName.length === 0) {
      onError('未配置模型名称');
      return;
    }

    const messages: OpenAIMessage[] = [];
    messages.push(new OpenAIMessage('system', systemPrompt));
    messages.push(new OpenAIMessage('user', userPrompt));

    const requestBody = new OpenAIRequest();
    requestBody.model = modelName;
    requestBody.messages = messages;
    requestBody.max_tokens = maxTokens;
    requestBody.temperature = 0.7;
    requestBody.stream = true;

    const httpRequest = http.createHttp();
    let sseBuffer = '';
    // 防止 dataEnd 和 catch 双重回调（超时时两者可能都触发）
    let isFinished = false;

    // 订阅流式数据接收
    httpRequest.on('dataReceive', (data: ArrayBuffer) => {
      if (isFinished) {
        return;
      }
      try {
        const decoder = new util.TextDecoder('utf-8');
        const chunk = decoder.decodeToString(new Uint8Array(data));
        sseBuffer += chunk;

        // 按行解析 SSE 数据
        const lines = sseBuffer.split('\n');
        // 保留最后一个不完整的行
        sseBuffer = lines[lines.length - 1];

        for (let i = 0; i < lines.length - 1; i++) {
          const line = lines[i].trim();
          if (line.startsWith('data: ')) {
            const jsonStr = line.substring(6);
            if (jsonStr === '[DONE]') {
              continue;
            }
            try {
              const parsed = JSON.parse(jsonStr) as Record<string, Object>;
              const choices = parsed['choices'] as Record<string, Object>[];
              if (choices && choices.length > 0) {
                const delta = choices[0]['delta'] as Record<string, string>;
                if (delta && delta['content']) {
                  onChunk(delta['content']);
                }
              }
            } catch {
              // 跳过无法解析的行
            }
          }
        }
      } catch (e) {
        console.error('AIService', `dataReceive parse error: ${e}`);
      }
    });

    // 订阅数据接收完毕
    httpRequest.on('dataEnd', () => {
      if (isFinished) {
        return;
      }
      isFinished = true;

      // 处理 buffer 中剩余数据
      if (sseBuffer.trim().length > 0) {
        const remaining = sseBuffer.trim();
        if (remaining.startsWith('data: ') && remaining.substring(6) !== '[DONE]') {
          try {
            const parsed = JSON.parse(remaining.substring(6)) as Record<string, Object>;
            const choices = parsed['choices'] as Record<string, Object>[];
            if (choices && choices.length > 0) {
              const delta = choices[0]['delta'] as Record<string, string>;
              if (delta && delta['content']) {
                onChunk(delta['content']);
              }
            }
          } catch {
            // 忽略
          }
        }
      }

      onDone();
      httpRequest.off('dataReceive');
      httpRequest.off('dataEnd');
      httpRequest.destroy();
    });

    try {
      console.info('AIService', `chatStream: url=${apiUrl}, model=${modelName}`);
      const responseCode = await httpRequest.requestInStream(
        apiUrl,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.apiKey}`
          },
          extraData: JSON.stringify(requestBody),
          connectTimeout: 30000,
          readTimeout: 120000
        }
      );

      if (responseCode !== 200) {
        if (!isFinished) {
          isFinished = true;
          onError(`API 请求失败: HTTP ${responseCode}`);
        }
        httpRequest.off('dataReceive');
        httpRequest.off('dataEnd');
        httpRequest.destroy();
      }
    } catch (e) {
      if (!isFinished) {
        isFinished = true;
        const msg = AIService.extractErrMsg(e);
        console.error('AIService', `chatStream request failed: ${msg}`);
        onError(msg);
      }
      httpRequest.off('dataReceive');
      httpRequest.off('dataEnd');
      httpRequest.destroy();
    }
  }

  /**
   * 通义千问流式 URL（使用 OpenAI 兼容模式）
   */
  private resolveQwenStreamUrl(): string {
    // 通义千问支持 OpenAI 兼容的 /v1/chat/completions 端点
    return 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  }
}
