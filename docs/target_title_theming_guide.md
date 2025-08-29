# Target Title Theme Customization Guide

## Overview
This guide explains how to customize the target title appearance in your IPSC shooting game using Godot's theming system.

## Available Theme Styles

### 1. Golden Military Style (`target_title_settings.tres`)
- **Font**: Bold Impact/Arial Black style
- **Color**: Golden yellow (#FFF233)
- **Style**: Military/tactical appearance with strong outline
- **Best for**: Traditional shooting ranges, military-themed games

### 2. Tactical Green Style (`target_title_tactical.tres`)
- **Font**: Monospace (Consolas/Courier New)
- **Color**: Bright green (#00FF33)
- **Style**: Night vision/tactical display appearance
- **Best for**: Tactical training, night shooting scenarios

### 3. Competitive Orange Style (`target_title_competitive.tres`)
- **Font**: Modern sans-serif (Roboto/Arial)
- **Color**: Competition orange (#FF6600)
- **Style**: Clean, modern competitive look
- **Best for**: IPSC competitions, modern shooting sports

## How to Apply Themes

### Method 1: In the Scene File (Current Implementation)
The theme is applied directly in `drills.tscn`:
```gdscript
[node name="TargetTypeTitle" type="Label" parent="TopContainer/TopLayout/HeaderContainer"]
label_settings = ExtResource("4_title_settings")
```

### Method 2: Through Code (Dynamic Switching)
You can change themes dynamically in `drills.gd`:
```gdscript
# Load different theme styles
@export var golden_style: LabelSettings = preload("res://theme/target_title_settings.tres")
@export var tactical_style: LabelSettings = preload("res://theme/target_title_tactical.tres")
@export var competitive_style: LabelSettings = preload("res://theme/target_title_competitive.tres")

func apply_theme_style(style_name: String):
    match style_name:
        "golden":
            target_type_title.label_settings = golden_style
        "tactical":
            target_type_title.label_settings = tactical_style
        "competitive":
            target_type_title.label_settings = competitive_style
```

## Customization Options

### Font Properties
- `font_size`: Size of the text (32-48 recommended)
- `font_color`: Main text color
- `font_weight`: Thickness (400=normal, 700=bold, 900=black)
- `font_style`: 0=normal, 1=italic

### Visual Effects
- `outline_size`: Thickness of text outline (2-4 recommended)
- `outline_color`: Color of the outline (usually dark)
- `shadow_size`: Drop shadow blur radius
- `shadow_color`: Shadow color (usually semi-transparent black)
- `shadow_offset`: Shadow position offset (Vector2)

### Color Recommendations for Shooting Games
- **High Visibility**: Bright yellow, orange, or white
- **Military/Tactical**: Green, amber, or white
- **Competition**: Orange, red, or blue
- **Avoid**: Colors that blend with background

## Creating Custom Fonts

### Adding Custom Font Files
1. Place font files in `res://fonts/` directory
2. Create a FontFile resource:
```gdscript
[ext_resource type="FontFile" path="res://fonts/your_font.ttf" id="custom_font"]
```
3. Reference in LabelSettings:
```gdscript
font = ExtResource("custom_font")
```

### Recommended Font Types for Shooting Games
- **Military**: Stencil, Military fonts, condensed sans-serif
- **Tactical**: Monospace (Courier, Consolas, Source Code Pro)
- **Modern**: Clean sans-serif (Roboto, Open Sans, Lato)
- **Competitive**: Bold sans-serif (Impact, Arial Black, Bebas Neue)

## Performance Considerations
- LabelSettings are more efficient than full Theme resources
- Outline and shadow effects have minimal performance impact
- Pre-load themes rather than creating them dynamically

## Testing Your Theme
1. Apply the theme in the editor
2. Test with different background colors
3. Check readability at different screen sizes
4. Verify contrast in game lighting conditions

## Advanced Styling

### Adding Background to Title
You can add a background panel behind the title:
1. Add a PanelContainer as parent of the Label
2. Create a StyleBoxFlat resource with:
   - Background color with transparency
   - Border colors and thickness
   - Corner radius for rounded edges

### Animation Support
LabelSettings work with Godot's animation system:
- Animate `font_color` for color changes
- Animate `outline_color` for glow effects
- Use Tween nodes for smooth transitions
