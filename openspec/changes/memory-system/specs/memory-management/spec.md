## ADDED Requirements

### Requirement: System SHALL provide memory management interface

The system SHALL provide a settings interface for managing the memory system including viewing, editing, and clearing memory data.

#### Scenario: Access memory management from Settings
- **WHEN** user navigates to Settings
- **THEN** system displays memory management options: Soul Profile, Reading Profile, Reading Stats, Data Management

### Requirement: System SHALL support viewing reading statistics

The system SHALL provide a reading statistics page showing aggregated data for the last 7 and 30 days.

#### Scenario: View reading statistics
- **WHEN** user navigates to Settings → "Reading Statistics"
- **THEN** system displays: total reads, total reading time, favorite count, top topics

#### Scenario: Toggle statistics period
- **WHEN** user switches between "7 days" and "30 days"
- **THEN** system updates displayed statistics for selected period

### Requirement: System SHALL support exporting memory data

The system SHALL allow users to export all memory files (SOUL.md, PROFILE.md, daily logs).

#### Scenario: Export memory data
- **WHEN** user selects Settings → Data Management → Export
- **THEN** system exports memory directory to user-accessible location

### Requirement: System SHALL support clearing memory data

The system SHALL allow users to clear all memory data with confirmation.

#### Scenario: Clear memory data
- **WHEN** user selects Settings → Data Management → Clear
- **THEN** system shows confirmation dialog warning about data loss

#### Scenario: Confirm memory clear
- **WHEN** user confirms clear action
- **THEN** system deletes all files in memory directory

### Requirement: System SHALL auto-clean old logs

The system SHALL automatically delete daily log files older than 30 days.

#### Scenario: Clean logs on app start
- **WHEN** MemoryService initializes
- **THEN** system checks for and deletes log files older than 30 days

#### Scenario: Preserve logs within retention period
- **WHEN** log files are within 30 days
- **THEN** system keeps those files unchanged

### Requirement: System SHALL support AI settings configuration

The system SHALL provide an interface for configuring AI service settings.

#### Scenario: Access AI settings
- **WHEN** user navigates to Settings → "AI Settings"
- **THEN** system displays AI configuration options

#### Scenario: Configure API key
- **WHEN** user enters API key in AI settings
- **THEN** system stores API key in preferences and enables AI features

#### Scenario: Show API key status
- **WHEN** user views AI settings
- **THEN** system shows whether API key is configured (masked) or missing

### Requirement: Memory directory SHALL be initialized on app start

The system SHALL ensure memory directory structure exists when app starts.

#### Scenario: Create memory directory structure
- **WHEN** MemoryService.init() is called
- **THEN** system creates {filesDir}/memory/ and {filesDir}/memory/daily/ directories if they don't exist
