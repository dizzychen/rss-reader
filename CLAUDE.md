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

Install dependencies before building:

```bash
ohpm install
```

## Architecture

**Three-layer architecture: Pages > Services (singletons) > Database/FileIO > Storage (RDB + Preferences + Filesystem)**

### Navigation

Two-level navigation:

1. **Tab navigation** in `Index.ets` — 4 embedded `@Component` tabs (HomePage, FeedsPage, StarredPage, MePage), not
   registered as routes. MePage includes an embedded search bar with debounced search.
2. **Page stack** via `router.pushUrl` — detail pages (ArticleDetailPage, FeedArticlesPage, AddFeedPage, SettingsPage,
   AISettingsPage, TagsManagePage, SoulEditPage, ProfileViewPage, ReadingStatsPage, DailyBriefingPage) registered in
   `entry/src/main/resources/base/profile/main_pages.json`

Tab refresh uses integer tick counters (`@State homeRefreshTick`, etc.) — incrementing the counter signals the tab child
component to call its `loadData()` method. A separate `homeFullReloadTick` signals a complete reload (used after
background refresh).

### State Management

Component-level only, no global store (no AppStorage/LocalStorage):
- `@State` for page-local state
- `@Prop` for one-way data flow (e.g., ArticleItemComponent)
- Callback functions for parent-child communication
- Data refresh via re-calling `loadData()` methods

### Service Layer

All services use singleton pattern via `getInstance()`. Key services in `entry/src/main/ets/service/`:

| Service              | Role                                                                              |
|----------------------|-----------------------------------------------------------------------------------|
| RssService           | RSS/Atom/RDF parsing via pure regex (no XML library), HTTP fetching               |
| DatabaseHelper       | RDB (relationalStore) wrapper for `rss_reader.db`                                 |
| FeedRefreshService   | Batch refresh orchestration + system notifications                                |
| AIService            | LLM integration (DashScope/OpenAI/DeepSeek/Groq/Custom), OpenAI-compatible API    |
| MemoryService        | Three-layer memory: SOUL.md, PROFILE.md, LESSONS.md, daily/*.md (behavior logs)   |
| MemoryFileHelper     | Raw file I/O for memory files (read/write/cleanup)                                |
| ProfileService       | Auto-generates user reading profile from 30-day behavior (EMA algorithm)          |
| RecommendService     | Personalized ranking (weights: summary 0.45, title 0.30, recency 0.20, feed 0.05) |
| SettingsService      | Preferences persistence                                                           |
| BriefingService      | Daily AI briefing generation                                                      |
| BackupService        | Backup/restore to public documents directory; checks backup existence             |
| OPMLService          | OPML parsing and generation (XML)                                                 |
| OPMLFileHelper       | File I/O for OPML import/export via file picker                                   |
| DataOperationHelper  | High-level coordinator for OPML, full backup/restore, memory export/reset         |
| WorkSchedulerManager | Background periodic feed refresh (20-120 min) via `RssRefreshExtension`           |

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
- **LESSONS.md** — System-managed lessons learned from behavior patterns (success/anti/optimization categories). Tracks
  hit/miss counts and confidence.
- **daily/YYYY-MM-DD.md** — Real-time behavior logs (READ, READ_END, STAR, UNSTAR, SKIP, SEARCH, RATE, AI_REC_HIT,
  REC_EXPOSURE). Markdown table format, debounced batch writes, 30-day auto-cleanup.

Templates in `entry/src/main/resources/rawfile/memory/`.

### Initialization Flow (EntryAbility.onCreate)

1. Init DatabaseHelper (RDB setup) and SettingsService (preferences)
2. Check backup restore prompt — if app has run before but DB has no feeds and public backup exists, emit `need_restore`
   event
3. Load rawfile templates (SOUL.md, PROFILE.md, LESSONS.md) and init MemoryService (directory structure + templates)
4. Register ProfileService callbacks (`regenerate` and `quickRefresh`) to avoid circular dependency
5. Load AI API config (provider, base URL, model, API key), auto-correct invalid DashScope domain
6. Run daily maintenance if needed (cleanup old logs, regenerate profile)
7. Restore background refresh WorkScheduler task
8. Mark app as run (`PREF_HAS_RUN_BEFORE`) for future backup-restore detection

### Background Tasks & System Extensions

- **RssRefreshExtension** (`extension/RssRefreshExtension.ets`) — `WorkSchedulerExtensionAbility` for periodic
  background feed refresh. Managed by `WorkSchedulerManager`. Actual execution interval is subject to system
  battery/power group restrictions (active apps min ~2 hours).
- **EntryBackupAbility** (`entrybackupability/EntryBackupAbility.ets`) — `BackupExtensionAbility` for system-triggered
  backup/restore (night charging, OS upgrade, device migration). Auto-backs up memory files, DB, and preferences as
  declared in `backup_config.json`. Uses `fullBackupOnly: false` so system auto-restores files to original paths.

## Key Conventions

- All data models defined in `entry/src/main/ets/model/Models.ets`
- All constants (DB table names, preference keys, defaults) centralized in `entry/src/main/ets/constants/Constants.ets`
- Single reusable component: `ArticleItemComponent` (used by HomePage, FeedArticlesPage, MePage, StarredPage)
- ArticleDetailPage renders via WebView with custom HTML template
- MePage includes a 400ms debounced search with `contains` matching on title+summary+content
- RSS parsing uses pure regex — no external XML parsing library
- RDB unavailable in Previewer; services handle gracefully with `if (!this.rdbStore) return []`
- EventHub (`context.eventHub`) for cross-ability events: notification taps (`notification_tap`) and backup restore
  prompts (`need_restore`)
- AppStorage for cold-start notification flag (`notification_cold_start`) between EntryAbility and Index

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
