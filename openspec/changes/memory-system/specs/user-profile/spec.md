## ADDED Requirements

### Requirement: System SHALL automatically generate user profile from behaviors

The system SHALL automatically generate and update user reading profile (PROFILE.md) based on the last 30 days of behavior data.

#### Scenario: Generate profile on first data availability
- **WHEN** system has accumulated sufficient behavior data (≥20 reads)
- **THEN** system generates initial PROFILE.md with calculated metrics

#### Scenario: Update profile daily
- **WHEN** app launches for the first time each day
- **THEN** system recalculates and updates PROFILE.md in background

### Requirement: User profile SHALL contain calculated interest weights

The profile SHALL include interest weights for topics/categories calculated using exponential moving average (EMA) algorithm:
- Formula: newWeight = α × newSignal + (1 - α) × oldWeight
- α = 0.3 (decay factor)
- newSignal = (readCount × 1 + starCount × 3) / totalReads

#### Scenario: Calculate topic interest weight
- **WHEN** profile update runs
- **THEN** system calculates weight for each topic and stores values between 0 and 1

#### Scenario: Include trend indicator
- **WHEN** interest weight changes by more than 0.05
- **THEN** system marks trend as ↑ (increase) or ↓ (decrease), otherwise →

### Requirement: User profile SHALL contain reading habit statistics

The profile SHALL include the following aggregated statistics:
- Active hours: time periods with most reading activity
- Average daily reads: mean articles read per day
- Average read duration: mean time spent per article
- Deep read rate: percentage of reads >5 minutes
- Star rate: percentage of reads resulting in favorites

#### Scenario: Calculate reading habits from 30-day data
- **WHEN** profile update runs
- **THEN** system aggregates statistics from daily logs within 30-day window

#### Scenario: Handle insufficient data
- **WHEN** less than 7 days of data available
- **THEN** system marks affected statistics as "insufficient data"

### Requirement: System SHALL provide profile viewing interface

The system SHALL provide a read-only interface to view the current user profile.

#### Scenario: View profile from Settings
- **WHEN** user navigates to Settings → "Reading Profile"
- **THEN** system displays formatted profile content with all metrics

#### Scenario: Manual profile refresh
- **WHEN** user clicks "Refresh" button on profile page
- **THEN** system regenerates profile and displays updated content

### Requirement: User profile SHALL be stored as Markdown file

The user profile SHALL be stored at `{filesDir}/memory/PROFILE.md` in human-readable Markdown format.

#### Scenario: Read user profile content
- **WHEN** system calls getProfile()
- **THEN** system returns the content of PROFILE.md as string

#### Scenario: Write user profile content
- **WHEN** system calls updateProfile(content)
- **THEN** system overwrites PROFILE.md with provided content
