## ADDED Requirements

### Requirement: System SHALL support AI-powered article ranking

The system SHALL rank articles on the home page using AI scoring based on user's memory context (Soul + Profile + Today's log).

#### Scenario: Rank articles with AI
- **WHEN** user enables "Smart" sort mode on home page
- **THEN** system sends article list with memory context to AI and sorts by returned scores

#### Scenario: Display sort mode toggle
- **WHEN** user views home page
- **THEN** system displays current sort mode ("Smart" or "Latest") with toggle option

### Requirement: AI ranking SHALL use memory context

The AI ranking request SHALL include:
- Soul profile content (SOUL.md)
- User profile content (PROFILE.md)  
- Today's reading log summary
- List of articles to rank (ID, title, source)

#### Scenario: Build AI context for ranking
- **WHEN** AI ranking is triggered
- **THEN** system assembles context from memory files and passes to AI service

#### Scenario: Handle missing memory data
- **WHEN** Soul or Profile is not available
- **THEN** system includes placeholder text in context and proceeds with ranking

### Requirement: AI SHALL return scores for articles

The AI SHALL return a JSON response with scores (1-10) for each article, where higher scores indicate higher relevance to user interests.

#### Scenario: Parse AI ranking response
- **WHEN** AI returns ranking response
- **THEN** system extracts scores and maps them to article IDs

#### Scenario: Sort articles by score
- **WHEN** scores are available for articles
- **THEN** system sorts articles in descending score order

### Requirement: AI ranking SHALL have fallback mechanism

The system SHALL fall back to time-based sorting when AI ranking fails or is unavailable.

#### Scenario: Fallback on API error
- **WHEN** AI API call fails (timeout, error, invalid response)
- **THEN** system falls back to sorting articles by publish time (newest first)

#### Scenario: Fallback when API key missing
- **WHEN** AI API key is not configured
- **THEN** system uses time-based sorting and shows hint to configure AI

### Requirement: AI ranking results SHALL be cached

The system SHALL cache AI ranking results for 1 hour to reduce API calls.

#### Scenario: Return cached results
- **WHEN** cached ranking exists and is less than 1 hour old
- **THEN** system returns cached results without calling AI

#### Scenario: Refresh cache on expiry
- **WHEN** cached ranking is older than 1 hour
- **THEN** system calls AI for fresh ranking and updates cache
