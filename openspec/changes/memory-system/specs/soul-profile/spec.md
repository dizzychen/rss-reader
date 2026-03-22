## ADDED Requirements

### Requirement: System SHALL provide Soul profile management interface

The system SHALL provide an interface for users to view and edit their Soul profile (SOUL.md), which contains personal characteristics, reading philosophy, and preferences.

#### Scenario: Access Soul profile from Settings
- **WHEN** user navigates to Settings → "My Reading Profile"
- **THEN** system displays a preview of current Soul profile content

#### Scenario: Edit Soul profile
- **WHEN** user clicks "Edit Profile" button on Soul profile page
- **THEN** system opens a text editor for modifying SOUL.md content

#### Scenario: Save Soul profile changes
- **WHEN** user saves changes to Soul profile
- **THEN** system overwrites SOUL.md with new content and shows success feedback

### Requirement: Soul profile SHALL follow defined structure

The Soul profile (SOUL.md) SHALL contain the following sections:
- Identity: profession, domain, current stage
- Thinking traits: cognitive preferences, learning style
- Reading philosophy: reading habits and principles
- Long-term pursuits: learning goals
- Not interested: explicit exclusions
- AI interaction preferences: communication style with AI

#### Scenario: Display structured profile preview
- **WHEN** user views Soul profile page
- **THEN** system displays each section with its label and content clearly separated

#### Scenario: Create default template for new users
- **WHEN** Soul profile does not exist and user opens profile page
- **THEN** system displays a template with all sections and placeholder text

### Requirement: System SHALL check Soul profile existence

The system SHALL be able to check whether a Soul profile has been initialized.

#### Scenario: Detect missing Soul profile
- **WHEN** Soul profile does not exist
- **THEN** hasSoul() returns false

#### Scenario: Detect existing Soul profile
- **WHEN** Soul profile exists with content
- **THEN** hasSoul() returns true

### Requirement: Soul profile SHALL be stored as Markdown file

The Soul profile SHALL be stored at `{filesDir}/memory/SOUL.md` in human-readable Markdown format.

#### Scenario: Read Soul profile content
- **WHEN** system calls getSoul()
- **THEN** system returns the content of SOUL.md as string

#### Scenario: Write Soul profile content
- **WHEN** system calls updateSoul(content)
- **THEN** system overwrites SOUL.md with provided content
