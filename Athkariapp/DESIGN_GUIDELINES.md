# Athkari Design Guidelines (UI/UX)

This document outlines the standard UI and UX patterns to maintain a premium, consistent experience across the Athkari app. Use these standards when implementing new features.

## 1. Core Color Palette

The app follows a **"Premium Dark Slate"** theme with vibrant accents.

| Element | Color / Variable | Description |
| :--- | :--- | :--- |
| **Background** | `AppColors.homeBackground` (#0F172A) | Deep slate blue. Use for all main screen bases. |
| **Surface (Cards)** | `AppColors.onboardingSurface` (#1e293b) | Slightly lighter slate. Use for distinct UI cards. |
| **Primary Accent** | `AppColors.onboardingPrimary` (#306ee8) | Deep Blue. Use for main CTA buttons, progress indicators, and active states. |
| **Highlights** | `AppColors.onboardingPrimary` | Used for active states and secondary indicators. |
| **Premium Gold** | `AppColors.homeBeigeCard` / `appSecondary` | **EXCLUSIVE** to the Home Screen Hero Card. Do not use elsewhere. |
| **Success / Completed** | `AppColors.appPrimary` | Same as Blue. Used for all progress and completion. |
| **Error** | `Color.red` | Used for destructive actions (e.g., Delete, Reset). |

## 2. Component Standards

### Cards & Surfaces
- **Corner Radius**: Standard is `24pt` to `32pt`.
- **Borders**: Subtle `1pt` border with white opacity (e.g., `Color.white.opacity(0.05)`).
- **Glassmorphism**: Use `.background(.ultraThinMaterial)` for floating elements (tab bars, headers).

### Buttons
- **Shape**: Primarily **Capsule** or **Circle**.
- **Shadows**: Accent-colored shadows with low opacity (e.g., `.shadow(color: .blue.opacity(0.3), radius: 10, y: 5)`).
- **Active States**: Use `AnimatedButtonStyles` where possible for tactile feedback.

### Icons
- **Source**: Always use **SF Symbols**.
- **Styling**: Often wrapped in a Circle with `10%` opacity of the icon's color.

## 3. Typography
- **Heading 1**: Large, bold, white (32pt+).
- **Headlines**: Semi-bold, white.
- **Body**: Medium weight, light gray/white (14pt-16pt) with high line spacing (1.2 - 1.4x).
- **Arabic numerals**: Always use `.arabicNumeral` extension for consistency in RTL.

## 4. UX & Motion
- **RTL Support**: Ensure all chevrons and back buttons point correctly for Arabic (back = `chevron.right`).
- **Haptics**: 
  - `light`: Incremental actions (counting).
  - `medium`: State changes (toggle, reset).
  - `notification(.success)`: Goal completion.
- **Animations**: Use `.spring(response: 0.3, dampingFraction: 0.7)` for UI transitions.

## 5. Implementation Rules
- NEVER use `.orange` or hardcoded amber hex codes. Use `AppColors.appSecondary` or `AppColors.onboardingPrimary`.
- Use `AppColors` extension instead of literal `Color` values.
- Maintain `dir="rtl"` logical consistency in SwiftUI (HStack layout).
