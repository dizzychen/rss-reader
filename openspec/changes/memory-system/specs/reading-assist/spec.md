## ADDED Requirements

### Requirement: System SHALL provide AI reading assistance

The system SHALL provide an AI-powered reading assistance feature in the article detail page that generates personalized analysis.

#### Scenario: Access reading assistance
- **WHEN** user taps "AI Analysis" button in article detail page toolbar
- **THEN** system generates and displays personalized article analysis

### Requirement: Reading assistance SHALL provide key takeaways

The AI analysis SHALL include 3 key takeaways from the article, each no more than 50 characters.

#### Scenario: Generate key takeaways
- **WHEN** reading assistance is triggered
- **THEN** AI extracts and displays 3 main points from the article

### Requirement: Reading assistance SHALL relate to user background

The AI analysis SHALL explain how the article content relates to the user's background, work, or learning goals based on their Soul profile.

#### Scenario: Generate personal relevance
- **WHEN** reading assistance is triggered AND Soul profile exists
- **THEN** AI explains how content connects to user's stated interests and goals

#### Scenario: Handle missing Soul profile
- **WHEN** reading assistance is triggered AND Soul profile does not exist
- **THEN** AI provides general relevance without personal context

### Requirement: Reading assistance SHALL suggest follow-up reading

The AI analysis SHALL suggest 1-2 directions for extended reading or learning.

#### Scenario: Generate reading suggestions
- **WHEN** reading assistance is triggered
- **THEN** AI provides suggestions for related topics or sources to explore

### Requirement: Reading assistance SHALL use article content

The AI analysis SHALL be based on the article's full content (truncated to 3000 characters if longer).

#### Scenario: Process full article content
- **WHEN** article content is less than 3000 characters
- **THEN** AI receives complete article content for analysis

#### Scenario: Process truncated article content
- **WHEN** article content exceeds 3000 characters
- **THEN** AI receives first 3000 characters for analysis

### Requirement: Reading assistance SHALL show loading state

The system SHALL display a loading indicator while AI analysis is being generated.

#### Scenario: Display loading state
- **WHEN** user requests AI analysis
- **THEN** system shows loading indicator until response is received

#### Scenario: Display error state
- **WHEN** AI analysis fails
- **THEN** system shows error message with option to retry
