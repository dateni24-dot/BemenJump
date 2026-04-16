import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import '../game/bemenjump_game.dart';
import 'platform_block.dart';

// ============================================================
// Player Component
// ============================================================
// 4b3: Key component properties:
//   - position: Vector2 - the x,y world position of the player
//   - size: Vector2 - width and height in pixels
//   - scale: Vector2 - scaling factor (1.0 = normal)
//   - anchor: Anchor - the reference point for position/rotation
//   - visibility: controlled by the 'isVisible' property on Component
//     When set to false, render() is skipped.
//
// 4b4: SpriteComponent - base class for rendering a single Sprite
//      This player extends SpriteAnimationGroupComponent which supports
//      multiple animations grouped by state (idle, run, jump).
//      - SpriteAnimation: a sequence of sprites played over time
//      - AnimationGroup: maps enum states to different SpriteAnimations
//        so we can switch between idle, run, jump animations.
//
// 4b6: We use RectangleHitbox (a Shape) for collision detection.
//      The hitbox is a Rectangle shape used to detect overlaps.
// ============================================================

enum PlayerState { idle, run, jump, fall }

class Player extends SpriteAnimationGroupComponent<PlayerState>
    with HasGameReference<BemenJumpGame>, KeyboardHandler, CollisionCallbacks {
  
  final CharacterType characterType;
  
  // Physics constants (JumpKing style)
  static const double gravity = 980.0;
  static const double maxJumpForce = -500.0;
  static const double minJumpForce = -200.0;
  static const double chargeRate = 2.0; // fills 0→1 in ~0.5 seconds
  static const double moveSpeed = 120.0;
  static const double maxFallSpeed = 600.0;

  // Grace period so collision jitter doesn't cut off the charge
  // (Flame's onCollisionEnd fires even on minor hitbox fluctuations)
  static const double _groundGrace = 0.15; // 150 ms
  double _groundTimer = 0.0;

  // Physics state
  Vector2 velocity = Vector2.zero();
  bool get isOnGround => _groundTimer > 0;
  bool isCharging = false;
  double chargeAmount = 0.0;
  int facing = 1; // 1 = right, -1 = left
  
  // Input state
  bool moveLeft = false;
  bool moveRight = false;
  bool jumpPressed = false;
  
  Player({
    required this.characterType,
    required Vector2 position,
  }) : super(
    position: position,
    // 4b3: size - the dimensions of the player sprite in game units
    size: Vector2(48, 48),
    // 4b3: scale - multiplier for rendering size
    scale: Vector2.all(1.0),
    // 4b3: anchor - the reference point (center-bottom for platformers)
    anchor: Anchor.bottomCenter,
  );

  @override
  Future<void> onLoad() async {
    // 4b4: Create SpriteAnimations from sprite sheet data
    // Each character has different colored sprites rendered procedurally
    final idle = await _createAnimation(PlayerState.idle, 4, 0.2);
    final run = await _createAnimation(PlayerState.run, 6, 0.1);
    final jump = await _createAnimation(PlayerState.jump, 2, 0.15);
    final fall = await _createAnimation(PlayerState.fall, 2, 0.15);
    
    // 4b4: AnimationGroup - maps each state to its animation
    animations = {
      PlayerState.idle: idle,
      PlayerState.run: run,
      PlayerState.jump: jump,
      PlayerState.fall: fall,
    };
    
    current = PlayerState.idle;
    
    // 4b6: RectangleHitbox - a Rectangle Shape for collision detection
    // This is a geometric shape (rectangle) used for physics
    add(RectangleHitbox(
      size: Vector2(28, 44),
      position: Vector2(10, 2),
    ));
  }

  // 4b4: Create sprite animation procedurally
  // Since we're generating pixel art sprites in code, we create
  // them as painted sprites rather than loading from files
  Future<SpriteAnimation> _createAnimation(
    PlayerState state, int frameCount, double stepTime,
  ) async {
    final sprites = <Sprite>[];
    for (int i = 0; i < frameCount; i++) {
      // Create a procedural sprite for this frame
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      _drawCharacterFrame(canvas, state, i);
      final picture = recorder.endRecording();
      final image = await picture.toImage(48, 48);
      sprites.add(Sprite(image));
    }
    return SpriteAnimation.spriteList(sprites, stepTime: stepTime);
  }

  // Draw character pixel art frame procedurally
  void _drawCharacterFrame(Canvas canvas, PlayerState state, int frame) {
    switch (characterType) {
      case CharacterType.eren:
        _drawEren(canvas, state, frame);
        break;
      case CharacterType.beru:
        _drawBeru(canvas, state, frame);
        break;
      case CharacterType.ai:
        _drawAi(canvas, state, frame);
        break;
    }
  }

  void _px(Canvas c, double x, double y, Color col) {
    c.drawRect(Rect.fromLTWH(x, y, 1, 1), Paint()..color = col);
  }

  void _rect(Canvas c, double x, double y, double w, double h, Color col) {
    c.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = col);
  }

  // =================== EREN YAEGER ===================
  void _drawEren(Canvas c, PlayerState state, int frame) {
    const sk = Color(0xFFc4956a), skS = Color(0xFFa87a50);
    const hair = Color(0xFF5c3a1e), hairD = Color(0xFF3a2010);
    const coat = Color(0xFF2d2d2d), coatL = Color(0xFF3d3d3d), coatD = Color(0xFF1a1a1a);
    const shirt = Color(0xFF555555), shirtL = Color(0xFF777777);
    const boot = Color(0xFF1a1a1a), bootL = Color(0xFF2d2d2d);
    const eye = Color(0xFF1a6a3a);
    const belt = Color(0xFF4a3020), beltB = Color(0xFF6a5040);
    
    double yOff = 0;
    if (state == PlayerState.idle) {
      yOff = frame == 1 || frame == 3 ? -1 : 0;
    } else if (state == PlayerState.jump) {
      yOff = -2;
    }
    
    final bx = 18.0, by = 10.0 + yOff;
    
    // Hair back
    _rect(c, bx-1, by, 14, 4, hairD);
    _rect(c, bx+10, by+1, 4, 6, hairD);
    _rect(c, bx+11, by+3, 3, 5, hair);
    // Head
    _rect(c, bx+1, by+2, 10, 10, sk);
    _rect(c, bx+2, by+1, 8, 1, sk);
    // Hair front
    _rect(c, bx, by, 12, 3, hair);
    _rect(c, bx-1, by+1, 2, 6, hair);
    _rect(c, bx+10, by+1, 2, 4, hair);
    _rect(c, bx+11, by+4, 2, 8, hair);
    // Eyes
    _px(c, bx+4, by+5, eye); _px(c, bx+5, by+5, eye);
    _px(c, bx+7, by+5, eye); _px(c, bx+8, by+5, eye);
    // Mouth
    _px(c, bx+5, by+8, skS); _px(c, bx+6, by+8, skS);
    // Neck
    _rect(c, bx+4, by+11, 4, 2, sk);
    // Coat
    final tby = by + 12;
    _rect(c, bx+1, tby, 10, 10, coat);
    _rect(c, bx+2, tby, 8, 10, coatL);
    _rect(c, bx+4, tby+1, 4, 3, shirt);
    // Belt
    _rect(c, bx+1, tby+8, 10, 2, belt);
    _rect(c, bx+5, tby+8, 2, 2, beltB);
    // Arms
    _rect(c, bx-1, tby+1, 2, 8, coat);
    _rect(c, bx+11, tby+1, 2, 8, coat);
    _px(c, bx-1, tby+8, sk); _px(c, bx+12, tby+8, sk);
    // Legs
    final lby = tby + 10;
    if (state == PlayerState.run) {
      final off = frame % 2 == 0 ? -1.0 : 1.0;
      _rect(c, bx+2, lby+off, 3, 7, coatD);
      _rect(c, bx+7, lby-off, 3, 7, coatD);
      _rect(c, bx+1, lby+5+off, 4, 3, boot);
      _rect(c, bx+6, lby+5-off, 4, 3, boot);
    } else if (state == PlayerState.jump || state == PlayerState.fall) {
      _rect(c, bx+2, lby-2, 3, 5, coatD);
      _rect(c, bx+7, lby-2, 3, 5, coatD);
      _rect(c, bx+2, lby+1, 3, 2, boot);
      _rect(c, bx+7, lby+1, 3, 2, boot);
    } else {
      _rect(c, bx+2, lby, 3, 7, coatD);
      _rect(c, bx+7, lby, 3, 7, coatD);
      _rect(c, bx+1, lby+5, 4, 3, boot);
      _rect(c, bx+6, lby+5, 4, 3, boot);
    }
  }

  // =================== BERU ===================
  void _drawBeru(Canvas c, PlayerState state, int frame) {
    const body = Color(0xFF0a0a1a), bodyL = Color(0xFF1a1a3a);
    const glow = Color(0xFF4a5aff), glowD = Color(0xFF2a2a8a);
    const eye = Color(0xFF6a7aff), eyeB = Color(0xFFaabbff);
    const claw = Color(0xFF1a1a2a);
    
    double yOff = state == PlayerState.jump ? -2 : 0;
    final bx = 16.0, by = 4.0 + yOff;
    
    // Head
    _rect(c, bx+4, by, 8, 3, body);
    _rect(c, bx+3, by+2, 10, 4, body);
    _rect(c, bx+5, by+1, 6, 1, bodyL);
    // Antennae
    _px(c, bx+3, by-2, glow); _px(c, bx+12, by-2, glow);
    // Eyes
    _px(c, bx+5, by+3, eye); _px(c, bx+6, by+3, eyeB);
    _px(c, bx+9, by+3, eye); _px(c, bx+10, by+3, eyeB);
    // Mandibles
    _px(c, bx+4, by+5, claw); _px(c, bx+11, by+5, claw);
    // Neck
    _rect(c, bx+5, by+6, 6, 2, body);
    // Torso
    final tby = by + 8;
    _rect(c, bx+3, tby, 10, 8, body);
    _rect(c, bx+4, tby+1, 8, 6, bodyL);
    // Glow
    _px(c, bx+7, tby+2, glow); _px(c, bx+8, tby+2, glow);
    _px(c, bx+5, tby+1, glow); _px(c, bx+10, tby+1, glow);
    // Arms
    _rect(c, bx+1, tby+1, 2, 6, body);
    _rect(c, bx+13, tby+1, 2, 6, body);
    _px(c, bx+1, tby+3, glowD); _px(c, bx+14, tby+3, glowD);
    // Waist
    _rect(c, bx+4, tby+8, 8, 2, body);
    _rect(c, bx+5, tby+8, 6, 1, glowD);
    // Legs
    final lby = tby + 10;
    if (state == PlayerState.run) {
      final off = frame % 2 == 0 ? -1.0 : 1.0;
      _rect(c, bx+3, lby+off, 3, 9, body);
      _rect(c, bx+10, lby-off, 3, 9, body);
    } else if (state == PlayerState.jump || state == PlayerState.fall) {
      _rect(c, bx+3, lby-3, 3, 6, body);
      _rect(c, bx+10, lby-3, 3, 6, body);
    } else {
      _rect(c, bx+3, lby, 3, 9, body);
      _rect(c, bx+10, lby, 3, 9, body);
      _rect(c, bx+2, lby+8, 2, 1, claw);
      _rect(c, bx+5, lby+8, 2, 1, claw);
      _rect(c, bx+9, lby+8, 2, 1, claw);
      _rect(c, bx+12, lby+8, 2, 1, claw);
    }
  }

  // =================== AI HOSHINO (CHIBI) ===================
  void _drawAi(Canvas c, PlayerState state, int frame) {
    const sk = Color(0xFFe8b888);
    const hair = Color(0xFF6030a0), hairD = Color(0xFF401880), hairL = Color(0xFF8050c0);
    const eyeC = Color(0xFF6030a0), eyeW = Color(0xFFffffff), eyeStar = Color(0xFFffee55);
    const blush = Color(0xFFff8899);
    const dressP = Color(0xFFff50a0), dressL = Color(0xFFff80c0);
    const dressY = Color(0xFFffe040);
    const boot = Color(0xFFff3088), bootL = Color(0xFFff60a8);
    const outline = Color(0xFF301050);
    const mic = Color(0xFFcccccc), micH = Color(0xFFe0e0e0);
    const white = Color(0xFFffffff);
    
    double yOff = state == PlayerState.jump ? -2 : 0;
    final cx = 15.0, cy = 2.0 + yOff;
    
    // Hair back
    _rect(c, cx+1, cy+10, 16, 22, hairD);
    _rect(c, cx+2, cy+12, 14, 20, hair);
    _rect(c, cx-1, cy+8, 4, 18, hairD);
    _rect(c, cx+0, cy+10, 3, 16, hair);
    _rect(c, cx+14, cy+10, 3, 20, hairD);
    // Head
    _rect(c, cx+3, cy, 12, 1, outline);
    _rect(c, cx+2, cy+1, 14, 1, sk);
    _rect(c, cx+2, cy+2, 14, 14, sk);
    _rect(c, cx+3, cy+16, 12, 1, sk);
    // Hair front
    _rect(c, cx+2, cy-1, 14, 1, hair);
    _rect(c, cx+1, cy, 16, 4, hair);
    _rect(c, cx+2, cy+3, 5, 2, hair);
    _rect(c, cx+11, cy+3, 5, 2, hair);
    _rect(c, cx+8, cy+1, 2, 2, hairL);
    _rect(c, cx+1, cy+5, 2, 10, hairD);
    _rect(c, cx+15, cy+5, 2, 10, hair);
    // Hair accessory
    _px(c, cx+14, cy+2, dressY); _px(c, cx+15, cy+1, dressY);
    // Eyes
    _rect(c, cx+4, cy+7, 4, 5, eyeW);
    _rect(c, cx+4, cy+7, 4, 1, outline);
    _rect(c, cx+5, cy+9, 2, 2, eyeC);
    _px(c, cx+5, cy+9, eyeStar);
    _rect(c, cx+10, cy+7, 4, 5, eyeW);
    _rect(c, cx+10, cy+7, 4, 1, outline);
    _rect(c, cx+11, cy+9, 2, 2, eyeC);
    _px(c, cx+11, cy+9, eyeStar);
    // Blush
    _px(c, cx+3, cy+11, blush); _px(c, cx+4, cy+11, blush);
    _px(c, cx+13, cy+11, blush); _px(c, cx+14, cy+11, blush);
    // Mouth
    _px(c, cx+8, cy+13, outline); _px(c, cx+9, cy+13, outline);
    // Body
    final by2 = cy + 18;
    _rect(c, cx+4, by2, 10, 3, dressP);
    _rect(c, cx+5, by2, 8, 1, dressL);
    _rect(c, cx+3, by2+1, 12, 2, dressP);
    _px(c, cx+8, by2, dressY); _px(c, cx+9, by2, dressY);
    // Skirt
    _rect(c, cx+2, by2+3, 14, 5, dressP);
    _rect(c, cx+1, by2+5, 16, 3, dressP);
    _rect(c, cx+1, by2+7, 16, 1, white);
    // Arms
    _rect(c, cx+2, by2+1, 2, 4, sk);
    _rect(c, cx+14, by2, 2, 3, sk);
    // Mic
    _rect(c, cx+15, by2-3, 2, 3, mic);
    _rect(c, cx+14, by2-4, 4, 2, micH);
    // Legs
    final ly = by2 + 8;
    if (state == PlayerState.run) {
      final off = frame % 2 == 0 ? -1.0 : 1.0;
      _rect(c, cx+4, ly+off, 3, 2, sk);
      _rect(c, cx+3, ly+2+off, 4, 4, boot);
      _rect(c, cx+3, ly+2+off, 4, 1, bootL);
      _rect(c, cx+8, ly-off, 3, 2, sk);
      _rect(c, cx+7, ly+2-off, 4, 4, boot);
      _rect(c, cx+7, ly+2-off, 4, 1, bootL);
    } else if (state == PlayerState.jump || state == PlayerState.fall) {
      _rect(c, cx+4, ly-3, 3, 2, sk);
      _rect(c, cx+3, ly-1, 4, 3, boot);
      _rect(c, cx+10, ly-3, 3, 2, sk);
      _rect(c, cx+9, ly-1, 4, 3, boot);
    } else {
      _rect(c, cx+5, ly, 3, 2, sk);
      _rect(c, cx+4, ly+2, 4, 4, boot);
      _rect(c, cx+4, ly+2, 4, 1, bootL);
      _rect(c, cx+10, ly, 3, 2, sk);
      _rect(c, cx+9, ly+2, 4, 4, boot);
      _rect(c, cx+9, ly+2, 4, 1, bootL);
    }
  }

  // 4b2: update - physics and input processing every frame
  @override
  void update(double dt) {
    super.update(dt);

    // Tick down ground grace timer each frame
    if (_groundTimer > 0) _groundTimer = (_groundTimer - dt).clamp(0.0, _groundGrace);

    // JumpKing mechanics: charge jump while on ground
    if (isOnGround) {
      // Horizontal movement only on ground
      velocity.x = 0;
      if (moveLeft) {
        velocity.x = -moveSpeed;
        facing = -1;
      }
      if (moveRight) {
        velocity.x = moveSpeed;
        facing = 1;
      }
      
      // Charge jump
      if (jumpPressed && !isCharging) {
        isCharging = true;
        chargeAmount = 0;
      }
      if (isCharging && jumpPressed) {
        chargeAmount = (chargeAmount + chargeRate * dt).clamp(0, 1);
      }
      if (isCharging && !jumpPressed) {
        // Release jump!
        final jumpForce = minJumpForce + (maxJumpForce - minJumpForce) * chargeAmount;
        velocity.y = jumpForce;
        
        // Add horizontal momentum based on direction
        if (moveLeft) velocity.x = -moveSpeed * 1.5;
        if (moveRight) velocity.x = moveSpeed * 1.5;
        
        _groundTimer = 0; // explicitly leave ground
        isCharging = false;
        chargeAmount = 0;
      }
    } else {
      // In air: apply gravity, no horizontal control (JumpKing style!)
      velocity.y = (velocity.y + gravity * dt).clamp(-1000, maxFallSpeed);
    }
    
    // Apply velocity
    position.x += velocity.x * dt;
    position.y += velocity.y * dt;
    
    // Wall boundaries
    position.x = position.x.clamp(20, 380);
    
    // Update animation state
    // 4b3: scale.x is used to flip the sprite horizontally
    scale.x = facing.toDouble();
    
    if (!isOnGround) {
      current = velocity.y < 0 ? PlayerState.jump : PlayerState.fall;
    } else if (velocity.x.abs() > 10) {
      current = PlayerState.run;
    } else if (isCharging) {
      current = PlayerState.idle; // Could be a charge animation
    } else {
      current = PlayerState.idle;
    }
  }

  // Handle keyboard input
  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    moveLeft = keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
               keysPressed.contains(LogicalKeyboardKey.keyA);
    moveRight = keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
                keysPressed.contains(LogicalKeyboardKey.keyD);
    jumpPressed = keysPressed.contains(LogicalKeyboardKey.space) ||
                  keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
                  keysPressed.contains(LogicalKeyboardKey.keyW);
    return true;
  }

  // 4b6: Collision detection with platforms
  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    
    if (other is PlatformBlock && velocity.y >= 0) {
      // Landing on platform from above
      final platformTop = other.position.y;
      if (position.y <= platformTop + 10) {
        position.y = platformTop;
        velocity.y = 0;
        velocity.x = 0;
        _groundTimer = _groundGrace; // refresh grace timer
      }
    }
  }

  // onCollisionEnd intentionally removed:
  // Flame fires it on minor hitbox fluctuations (jitter), which would
  // cut off the jump charge. _groundTimer expires naturally in update().
}
