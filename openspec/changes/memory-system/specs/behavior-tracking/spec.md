## ADDED Requirements

### Requirement: System SHALL automatically record user reading behaviors

The system SHALL automatically record the following user behaviors without requiring manual action:
- READ: When user enters an article detail page
- READ_END: When user leaves an article detail page
- STAR: When user adds an article to favorites
- UNSTAR: When user removes an article from favorites
- SKIP: When user scrolls past an article within 1 second of exposure
- SEARCH: When user executes a search query

#### Scenario: Record READ behavior on article entry
- **WHEN** user navigates to ArticleDetailPage
- **THEN** system records a READ behavior with timestamp, articleId, articleTitle, and feedTitle

#### Scenario: Record READ_END behavior on article exit
- **WHEN** user leaves ArticleDetailPage
- **THEN** system records a READ_END behavior with duration (seconds) and scrollDepth (0-100%)

#### Scenario: Record STAR behavior on favorite action
- **WHEN** user clicks the star/favorite button on an article
- **THEN** system records a STAR behavior with articleId

#### Scenario: Record UNSTAR behavior on unfavorite action
- **WHEN** user clicks to remove an article from favorites
- **THEN** system records an UNSTAR behavior with articleId

#### Scenario: Record SEARCH behavior on search execution
- **WHEN** user submits a search query in SearchPage
- **THEN** system records a SEARCH behavior with the searchQuery text

### Requirement: Behaviors SHALL be stored in daily Markdown log files

The system SHALL store all recorded behaviors in daily log files using Markdown table format, located at `{filesDir}/memory/daily/YYYY-MM-DD.md`.

#### Scenario: Create daily log file on first behavior
- **WHEN** first behavior of the day is recorded
- **THEN** system creates a new log file with header containing date and table structure

#### Scenario: Append behavior to existing log file
- **WHEN** subsequent behaviors are recorded on the same day
- **THEN** system appends new table rows to the existing daily log file

### Requirement: Behavior recording SHALL use debounce mechanism

The system SHALL use a 500ms debounce mechanism to batch multiple behaviors into a single file write operation.

#### Scenario: Batch multiple rapid behaviors
- **WHEN** multiple behaviors occur within 500ms
- **THEN** system batches all behaviors and writes them in a single file operation

#### Scenario: Immediate write after debounce timeout
- **WHEN** no new behaviors occur for 500ms after the last behavior
- **THEN** system flushes the behavior queue to the log file

### Requirement: Behavior recording SHALL be silent and non-blocking

The system SHALL record behaviors without affecting user experience - no UI feedback, no blocking operations.

#### Scenario: Silent recording during reading
- **WHEN** user is reading an article
- **THEN** behavior recording happens in the background without any visible indication

#### Scenario: Non-blocking file operations
- **WHEN** behavior recording encounters a file operation delay
- **THEN** user interaction remains responsive and unaffected
