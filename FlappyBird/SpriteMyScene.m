//
//  SpriteMyScene.m
//  FlappyBird
//
//  Created by JOJO on 28/2/14.
//  Copyright (c) 2014年 JOJO. All rights reserved.
//

#import "SpriteMyScene.h"

@interface SpriteMyScene() <SKPhysicsContactDelegate>{
    SKSpriteNode *_bird;
    SKColor *_skyColor;
    SKTexture* _pipeTexture1;
    SKTexture* _pipeTexture2;
    SKAction* _moveAndRemovePipes;
    SKNode *_moving;
    SKNode *_pipes;
    BOOL _canRestart;
}
@end

@implementation SpriteMyScene

static const uint32_t birdCategory = 1 << 0;
static const uint32_t worldCategory = 1 << 1;
static const uint32_t pipeCategory = 1 << 2;
static NSInteger const kVerticalPipeGap = 150;

-(id)initWithSize:(CGSize)size {    
    if (self = [super initWithSize:size]) {
        _canRestart = NO;
        self.physicsWorld.gravity = CGVectorMake(0.0, -5.0);
        self.physicsWorld.contactDelegate = self;
        //background
        _skyColor = [SKColor colorWithRed:113.0/255.0 green:197.0/255.0 blue:207.0/255.0 alpha:1.0];
        [self setBackgroundColor:_skyColor];
        
        _moving = [SKNode node];
        [self addChild:_moving];
        
        _pipes = [SKNode node];
        [_moving addChild:_pipes];
        
        //create bird
        SKTexture *birdTexture1 = [SKTexture textureWithImageNamed:@"Bird1"];
        birdTexture1.filteringMode = SKTextureFilteringNearest;
        SKTexture *birdTexture2 = [SKTexture textureWithImageNamed:@"Bird2"];
        birdTexture2.filteringMode = SKTextureFilteringNearest;
        _bird = [SKSpriteNode spriteNodeWithTexture:birdTexture1];
        [_bird setScale:2.0];
        _bird.position = CGPointMake(CGRectGetMidX(self.frame)/2, CGRectGetMidY(self.frame));
        
        _bird.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:_bird.size.height/2];
        _bird.physicsBody.dynamic = YES;
        _bird.physicsBody.allowsRotation = NO;
        _bird.physicsBody.categoryBitMask = birdCategory;
        _bird.physicsBody.collisionBitMask = worldCategory | pipeCategory;
        _bird.physicsBody.contactTestBitMask = worldCategory | pipeCategory;
        [self addChild:_bird];
        
        //bird action
        SKAction *flap = [SKAction repeatActionForever:[SKAction animateWithTextures:@[birdTexture1, birdTexture2] timePerFrame:0.1]];
        [_bird runAction:flap];
        
        //create ground
        SKTexture *groundTexture = [SKTexture textureWithImageNamed:@"Ground"];
        groundTexture.filteringMode = SKTextureFilteringNearest;
        SKAction *moveGroundSprite = [SKAction moveByX:-groundTexture.size.width*2 y:0 duration:0.02*groundTexture.size.width*2];
        SKAction *resetGroundSprite = [SKAction moveByX:groundTexture.size.width*2 y:0 duration:0];
        SKAction *moveGroundSpriteForever = [SKAction repeatActionForever:[SKAction sequence:@[moveGroundSprite, resetGroundSprite]]];
        
        for (int i=0; i<2+self.frame.size.width/(groundTexture.size.width*2); ++i) {
            SKSpriteNode *sprite = [SKSpriteNode spriteNodeWithTexture:groundTexture];
            [sprite setScale:2.0];
            sprite.position = CGPointMake(i*sprite.size.width, sprite.size.height/2);
            [sprite runAction:moveGroundSpriteForever];
//            [self addChild:sprite];
            [_moving addChild:sprite];
        }
        
        //create skyline
        SKTexture *skyTexture = [SKTexture textureWithImageNamed:@"Skyline"];
        skyTexture.filteringMode = SKTextureFilteringNearest;
        SKAction *moveSkylineSprite = [SKAction moveByX:-skyTexture.size.width*2 y:0 duration:0.1*skyTexture.size.width*2];
        SKAction *resetSkylineSprite = [SKAction moveByX:skyTexture.size.width*2 y:0 duration:0];
        SKAction *moveSkylineSpriteForever = [SKAction repeatActionForever:[SKAction sequence:@[moveSkylineSprite, resetSkylineSprite]]];
        
        for (int i=0; i<2+self.frame.size.width/(skyTexture.size.width*2); ++i) {
            SKSpriteNode *sprite = [SKSpriteNode spriteNodeWithTexture:skyTexture];
            [sprite setScale:2.0];
            sprite.zPosition = -20;
            sprite.position = CGPointMake(i*sprite.size.width, sprite.size.height/2+groundTexture.size.height*2);
            [sprite runAction:moveSkylineSpriteForever];
//            [self addChild:sprite];
            [_moving addChild:sprite];
        }
        
        //create ground physics container
        SKNode *dummy = [SKNode node];
        dummy.position = CGPointMake(0, groundTexture.size.height);
        dummy.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(self.frame.size.width, groundTexture.size.height*2)];
        dummy.physicsBody.dynamic = NO;
        dummy.physicsBody.categoryBitMask = worldCategory;
        [self addChild:dummy];
        
        //create pipe
        _pipeTexture1 = [SKTexture textureWithImageNamed:@"Pipe1"];
        _pipeTexture1.filteringMode = SKTextureFilteringNearest;
        _pipeTexture2 = [SKTexture textureWithImageNamed:@"Pipe2"];
        _pipeTexture2.filteringMode = SKTextureFilteringNearest;

        CGFloat distanceToMove = self.frame.size.width + 2*_pipeTexture1.size.width;
        SKAction *movePipes = [SKAction moveByX:-distanceToMove y:0 duration:0.01*distanceToMove];
        SKAction *removePipes = [SKAction removeFromParent];
        _moveAndRemovePipes = [SKAction sequence:@[movePipes, removePipes]];
        
        SKAction *spawn = [SKAction performSelector:@selector(spawnPipes) onTarget:self];
        SKAction *delay = [SKAction waitForDuration:2];
        SKAction *spawnThenDelay = [SKAction sequence:@[spawn, delay]];
        SKAction *spawnThenDelayForever = [SKAction repeatActionForever:spawnThenDelay];
        [self runAction:spawnThenDelayForever];
    }
    return self;
}


-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Called when a touch begins */
    if (_moving.speed > 0) {
        _bird.physicsBody.velocity = CGVectorMake(0, 0);
        [_bird.physicsBody applyImpulse:CGVectorMake(0, 8)];
    }else if (_canRestart) {
        [self resetScene];
    }
}

CGFloat clamp(CGFloat min, CGFloat max, CGFloat value) {
    if (value > max) {
        return max;
    }else if (value < min) {
        return min;
    }else {
        return value;
    }
}
-(void)resetScene {
    //move bird to original position and rset velocity
    _bird.position = CGPointMake(self.frame.size.width/4, CGRectGetMidY(self.frame));
    _bird.physicsBody.velocity = CGVectorMake(0, 0);
    
    //remove all existing pipes
    [_pipes removeAllChildren];
    
    //reset _canReset
    _canRestart = NO;
    
    //restart annimation
    _moving.speed = 1;
}

-(void)spawnPipes {
    SKNode *pipePair = [SKNode node];
    pipePair.position = CGPointMake(self.frame.size.width+_pipeTexture1.size.width,0);
    pipePair.zPosition = -10;
    CGFloat y = arc4random()%(NSInteger)(self.frame.size.height/3);
    
    SKSpriteNode *pipe1 = [SKSpriteNode spriteNodeWithTexture:_pipeTexture1];
    [pipe1 setScale:2];
    pipe1.position = CGPointMake(0, y);
    pipe1.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:pipe1.size];
    pipe1.physicsBody.dynamic = NO;
    pipe1.physicsBody.categoryBitMask = pipeCategory;
    pipe1.physicsBody.contactTestBitMask = birdCategory;
    [pipePair addChild:pipe1];
    
    SKSpriteNode *pipe2 = [SKSpriteNode spriteNodeWithTexture:_pipeTexture2];
    [pipe2 setScale:2];
    pipe2.position = CGPointMake(0, y+pipe1.size.height+kVerticalPipeGap);
    pipe2.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:pipe2.size];
    pipe2.physicsBody.dynamic = NO;
    pipe2.physicsBody.categoryBitMask = pipeCategory;
    pipe2.physicsBody.contactTestBitMask = birdCategory;
    [pipePair addChild:pipe2];
    
    [pipePair runAction:_moveAndRemovePipes];
    [_pipes addChild:pipePair];
//    [self addChild:pipePair];
//    [_moving addChild:pipePair];
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
    _bird.zRotation = clamp(-1, 0.5, _bird.physicsBody.velocity.dy*(_bird.physicsBody.velocity.dy < 0 ? 0.003 : 0.001));
}

-(void)didBeginContact:(SKPhysicsContact *)contact {
    if(_moving.speed > 0) {
        _moving.speed = 0;
        
        [self removeActionForKey:@"flash"];
        [self runAction:[SKAction sequence:@[[SKAction repeatAction:[SKAction sequence:@[[SKAction runBlock:^{
            self.backgroundColor = [SKColor redColor];
        }], [SKAction waitForDuration:0.05], [SKAction runBlock:^{
            self.backgroundColor = _skyColor;
        }], [SKAction waitForDuration:0.05]]] count:4], [SKAction runBlock:^{
            _canRestart = YES;
        }]]] withKey:@"flash"];
    }
}












@end
