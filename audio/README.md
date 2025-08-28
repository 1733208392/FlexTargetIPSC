# Sample Audio Files for IPSC Steel Target Sounds

This folder contains audio files for realistic steel target impact effects.

## 📁 Recommended File Structure:

```
audio/
├── steel_ping.wav          # Main IPSC target impact
├── steel_clang.wav         # Heavy steel impact (paddles)
├── metal_snap.wav          # Quick reactive target sound (poppers)
├── ricochet.wav           # Bullet ricochet effect (optional)
└── dirt_impact.wav        # Miss sound for ground impacts (optional)
```

## 🎵 Where to Download:

### Freesound.org (Recommended)
- Search: "steel ping", "metal impact", "bullet steel"
- High quality, Creative Commons licensed
- URL: https://freesound.org

### Specific Sound Recommendations:
1. **Steel Ping**: Search "steel ping target" or "metal ping"
2. **Steel Clang**: Search "metal clang" or "steel plate"
3. **Metal Snap**: Search "metal snap" or "steel pop"

## 🔧 How to Use:

1. **Download** sound files from recommended sources
2. **Save** them in this `/audio/` folder
3. **Open** `res://scene/bullet.tscn` in Godot
4. **Select** the bullet node
5. **Assign** the audio file to "Impact Sound" property
6. **Test** by shooting targets in any scene!

## 🎯 Quick Setup:

For immediate testing, you can use any short metal impact sound:
- Duration: 0.5-2.0 seconds
- Format: .wav or .ogg
- Quality: 44.1kHz recommended

The sound system is ready - just add your audio files!
