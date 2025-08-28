# Paddle Shader Troubleshooting Guide

## Testing the Shader Effect

### 1. **Quick Test Controls:**
- **SPACE key**: Manually test shader effects (sets fall_progress to 0.5)
- **R key**: Reset paddle to initial state
- **Click circle area**: Trigger full fall animation
- **Click stand area**: Test shader manually

### 2. **Debug Output to Check:**
When you run the scene, you should see these console messages:

```
Shader material found!
Shader: [Shader object]
Fall progress: 0.0
```

If you see "ERROR: No shader material found on sprite!" then the material isn't properly assigned.

### 3. **What Should Happen:**

**When you press SPACE:**
- Paddle should immediately show shader effects:
  - Scale down to 50%
  - Rotate 45 degrees
  - Apply perspective distortion
  - Darken/fade slightly

**When you click the circle:**
- Detailed debug messages should appear
- Animation should play over 1.2 seconds
- Paddle should shrink, rotate, and fall with perspective

### 4. **Common Issues and Fixes:**

#### Issue: "No shader material found"
**Fix:** Check that the material is properly assigned in the scene:
- Open paddle.tscn
- Select PopperSprite node
- In Inspector → CanvasItem → Material should show paddle_fall_material.tres

#### Issue: Shader parameters not animating
**Fix:** Check the animation tracks:
- Open paddle.tscn
- Select AnimationPlayer node
- Check that animation "fall_down" exists
- Verify the tracks point to correct shader parameters

#### Issue: Only Y movement, no shader effects
**Fix:** Material might be using wrong shader:
- Open paddle_fall_material.tres
- Ensure "Shader" points to paddle_fall.gdshader
- Check that shader_parameter values are set

### 5. **Manual Verification:**

#### Test 1: Check Material Assignment
```gdscript
# In paddle.gd _ready() function, you should see:
func test_shader_material():
    var shader_material = sprite.material as ShaderMaterial
    if shader_material:
        print("✓ Shader material found!")
        print("✓ Shader: ", shader_material.shader)
    else:
        print("✗ ERROR: No shader material!")
```

#### Test 2: Manual Parameter Setting
```gdscript
# Press SPACE to run:
func test_shader_effects():
    var shader_material = sprite.material as ShaderMaterial
    if shader_material:
        shader_material.set_shader_parameter("fall_progress", 0.5)
        # Should see immediate visual change
```

### 6. **Expected Visual Results:**

- **fall_progress = 0.0**: Normal paddle appearance
- **fall_progress = 0.5**: 50% smaller, rotated, slightly faded
- **fall_progress = 1.0**: Very small, heavily rotated, heavily faded

### 7. **If Still No Effect:**

1. **Check Godot Version**: Ensure you're using Godot 4.x
2. **Shader Compilation**: Look for shader errors in Output panel
3. **Material Path**: Verify all file paths are correct
4. **Scene Structure**: Ensure nodes are properly nested

### 8. **Fallback Test:**

If shader still doesn't work, try this simple test shader:

```glsl
shader_type canvas_item;
uniform float test_param : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    COLOR = texture(TEXTURE, UV) * (1.0 - test_param * 0.5);
}
```

This should at least fade the sprite when test_param is animated.

## Next Steps

Once the shader is working:
1. Fine-tune the effect parameters
2. Add sound effects
3. Add particle effects for dust/debris
4. Implement scoring system
