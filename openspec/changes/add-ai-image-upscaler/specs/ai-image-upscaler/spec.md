## ADDED Requirements

### Requirement: CPU bicubic upscaling
The system SHALL provide a `CpuImageUpscaler` class that implements the `ImageUpscaler` interface using genuine bicubic pixel interpolation. It SHALL decode the input bytes, resize using bicubic interpolation at the requested `scaleFactor`, and return the re-encoded output bytes with correct `outWidth` and `outHeight`. It SHALL report `MlBackend.cpu` as the backend.

#### Scenario: 2x upscale returns doubled dimensions
- **WHEN** `upscale` is called with `scaleFactor: 2`, `srcWidth: 100`, `srcHeight: 80`
- **THEN** the returned `UpscaleResult` has `outWidth: 200`, `outHeight: 160`, `backend: MlBackend.cpu`, and `bytes` that differ from the input (real interpolation occurred)

#### Scenario: 1x upscale returns identity dimensions
- **WHEN** `upscale` is called with `scaleFactor: 1`, `srcWidth: 50`, `srcHeight: 50`
- **THEN** the returned `UpscaleResult` has `outWidth: 50`, `outHeight: 50` and non-null bytes

### Requirement: CpuImageUpscaler is the default provider
The `imageUpscalerProvider` SHALL return a `CpuImageUpscaler` instance as the default implementation.

#### Scenario: Provider resolves to CpuImageUpscaler
- **WHEN** `imageUpscalerProvider` is read in a ProviderScope without overrides
- **THEN** the returned instance is a `CpuImageUpscaler`

### Requirement: Manga viewer upscale action
The manga viewer SHALL display a "高画質化 / Upscale" icon button in the AppBar. Tapping it SHALL upscale the current page at 2× using `imageUpscalerProvider` and display the upscaled image. A progress indicator SHALL be shown while upscaling is in progress. On error, a localized error message SHALL be displayed.

#### Scenario: Upscale button is visible in AppBar
- **WHEN** the manga viewer screen is displayed with controls visible
- **THEN** an `Icons.auto_fix_high` icon button with the localized upscale tooltip is present in the AppBar

#### Scenario: Upscale in-progress shows indicator
- **WHEN** the upscale action is tapped and the upscaler has not yet returned
- **THEN** a `CircularProgressIndicator` is visible

### Requirement: Localization for upscale UI
The system SHALL provide localized strings for the upscale action label, progress indicator label, and error message in both `ja` and `en` locales. Keys: `mangaUpscaleAction`, `mangaUpscaleInProgress`, `mangaUpscaleError`.

#### Scenario: Japanese locale upscale action label
- **WHEN** locale is `ja` and the upscale icon button tooltip is rendered
- **THEN** the tooltip reads "高画質化"

#### Scenario: English locale upscale action label
- **WHEN** locale is `en` and the upscale icon button tooltip is rendered
- **THEN** the tooltip reads "Upscale"
