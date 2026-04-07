# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HarmonyOS NEXT (API 6.0+) RSS reader app built with ArkTS/ArkUI (Stage Model). Bundle: `com.dizzy.rssreader`. An intelligent RSS reader combining subscription management with AI-powered summarization, personalized recommendations, and a three-layer memory system.

## Build & Development Commands

```bash
# Build HAP (debug)
hvigorw assembleHap --mode module -p module=entry@default

# Build release with obfuscation
hvigorw assembleHap --mode module -p module=entry@default --buildMode release

# Lint
hvigorw lint

# Build device-side tests
hvigorw assembleHap --mode module -p module=entry@ohosTest
# Then deploy via DevEco Studio: Run > Run 'entry' (select ohosTest variant)
# Results appear in Logcat
```

Full builds and device deployment require DevEco Studio. SDK: 6.0.0~6.0.2.

## Architecture

**Three-layer architecture: Pages > Services (singletons) > Database/FileIO > Storage (RDB + Preferences + Filesystem)**

### Navigation

Two-level navigation:
1. **Tab navigation** in `Index.ets` — 4 embedded `@Component` tabs (HomePage, FeedsPage, StarredPage, SearchPage), not registered as routes
2. **Page stack** via `router.pushUrl` — detail pages (ArticleDetailPage, FeedArticlesPage, AddFeedPage, SettingsPage, etc.) registered in `entry/src/main/resources/base/profile/main_pages.json`

### State Management

Component-level only, no global store (no AppStorage/LocalStorage):
- `@State` for page-local state
- `@Prop` for one-way data flow (e.g., ArticleItemComponent)
- Callback functions for parent-child communication
- Data refresh via re-calling `loadData()` methods

### Service Layer

All services use singleton pattern via `getInstance()`. Key services in `entry/src/main/ets/service/`:

| Service | Role |
|---------|------|
| RssService | RSS/Atom/RDF parsing via pure regex (no XML library), HTTP fetching |
| DatabaseHelper | RDB (relationalStore) wrapper for `rss_reader.db` |
| FeedRefreshService | Batch refresh orchestration + system notifications |
| AIService | LLM integration (DashScope/OpenAI/DeepSeek/Groq/Custom), OpenAI-compatible API |
| MemoryService | Three-layer memory: SOUL.md (user identity), PROFILE.md (auto-generated), daily/*.md (behavior logs) |
| ProfileService | Auto-generates user reading profile from 30-day behavior (EMA algorithm) |
| RecommendService | Personalized ranking (weights: summary 0.45, title 0.30, recency 0.20, feed 0.05) |
| SettingsService | Preferences persistence |
| BriefingService | Daily AI briefing generation |
| WorkSchedulerManager | Background periodic feed refresh (20-120 min) |

### Database Schema

Database: `rss_reader.db`, security level S1, 5 tables:
- `groups` (id, name, sort_order)
- `feeds` (id, title, **url UNIQUE**, site_url, icon_url, description, group_id, last_updated)
- `articles` (id, feed_id, guid, title, summary, content, url, author, published_at, is_read, is_starred, cover_image, cached_at, ai_summary — **UNIQUE(feed_id, guid)**, insert uses ON_CONFLICT_IGNORE)
- `tags` (id, **name UNIQUE**)
- `article_tags` (article_id, tag_id, **PRIMARY KEY(article_id, tag_id)**)

Cascade behaviors: deleting a feed cascades to its articles/tags; deleting a group moves its feeds to default group (id=1). Cache cleanup preserves starred articles.

### Memory System

Three-layer architecture stored in `{context.filesDir}/memory/`:
- **SOUL.md** — User-edited identity (career, interests, goals). Initialized from template in `rawfile/memory/`, never overwritten by system.
- **PROFILE.md** — Auto-generated daily from 30-day behavior data (interest weights via EMA + read duration, AI insights). Updated by ProfileService.
- **daily/YYYY-MM-DD.md** — Real-time behavior logs (READ, READ_END, STAR, UNSTAR, SKIP, SEARCH, RATE, AI_REC_HIT). Markdown table format, debounced batch writes, 30-day auto-cleanup.

Templates in `entry/src/main/resources/rawfile/memory/`.

### Initialization Flow (EntryAbility.onCreate)

1. Init DatabaseHelper (RDB setup) and SettingsService (preferences)
2. Init MemoryService (directory structure + templates)
3. Register ProfileService callback (avoids circular dependency)
4. Load AI API config, auto-correct invalid DashScope domain
5. Run daily maintenance (cleanup old logs, regenerate profile)
6. Restore background refresh WorkScheduler task

## Key Conventions

- All data models defined in `entry/src/main/ets/model/Models.ets`
- All constants (DB table names, preference keys, defaults) centralized in `entry/src/main/ets/constants/Constants.ets`
- Single reusable component: `ArticleItemComponent` (used by HomePage, FeedArticlesPage, SearchPage, StarredPage)
- ArticleDetailPage renders via WebView with custom HTML template
- SearchPage uses 400ms debounced search with `contains` matching on title+summary+content
- RSS parsing uses pure regex — no external XML parsing library
- RDB unavailable in Previewer; services handle gracefully with `if (!this.rdbStore) return []`
- EventBus singleton (`service/EventBus.ets`) for cross-component events (e.g., FEED_ADDED)
- EventHub for notification tap events between EntryAbility and Index

## Testing

Device-side tests in `entry/src/ohosTest/ets/tests/` using Hypium + Hamock:
- RssServiceTest, RssUtilsTest — RSS parsing, date formatting, HTML handling, pure utility functions
- DatabaseHelperTest — CRUD, cascade deletes, unread counts
- FeedRefreshServiceTest — refresh counting, notification logic
- ConstantsTest, ModelsTest — validation and model completeness

Test entry: `entry/src/ohosTest/ets/test/List.test.ets` aggregates all test imports.
Local tests (`entry/src/test/`) are template-only.

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| @luvi/lv-markdown-in | ^2.0.0 | Markdown rendering |
| @ohos/hypium | 1.0.25 | Test framework (dev) |
| @ohos/hamock | 1.0.0 | Mock toolkit (dev) |

## Git Commit Style

Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`
