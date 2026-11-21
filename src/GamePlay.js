var AMOUNT_DIAMONDS = 30;
var AMOUNT_BUBBLES = 30;
var GAME_TIME = 30;              // segundos
var POINTS_PER_DIAMOND = 100;
var POINTS_PER_SECOND_LEFT = 50; // bonus al ganar
var HORSE_FOLLOW = 0.02;         // suavidad del seguimiento (a 60 FPS)
var MAX_PLACEMENT_TRIES = 500;
var HIGHSCORE_KEY = 'atlantis_highscore';

// La música vive fuera del state para no duplicarse al reiniciar
var music = null;

function loadHighScore() {
    try {
        return parseInt(localStorage.getItem(HIGHSCORE_KEY), 10) || 0;
    } catch (e) {
        return 0;
    }
}

function saveHighScore(score) {
    try {
        localStorage.setItem(HIGHSCORE_KEY, String(score));
    } catch (e) { /* sin almacenamiento, no pasa nada */ }
}

var GamePlayManager = {
    init: function() {
        game.scale.scaleMode = Phaser.ScaleManager.SHOW_ALL;
        game.scale.pageAlignHorizontally = true;
        game.scale.pageAlignVertically = true;

        this.flagFirstMouseDown = false;
        this.amountDiamondsCaught = 0;
        this.endGame = false;
        this.canRestart = false;
        this.countSmile = -1;
        this.highScore = loadHighScore();
    },

    preload: function() {
        game.load.image('background', 'assets/images/background.png');
        game.load.spritesheet('horse', 'assets/images/horse.png', 84, 156, 2);
        game.load.spritesheet('diamonds', 'assets/images/diamonds.png', 81, 84, 4);

        game.load.image('explosion', 'assets/images/explosion.png');

        game.load.image('shark', 'assets/images/shark.png');
        game.load.image('fishes', 'assets/images/fishes.png');
        game.load.image('mollusk', 'assets/images/mollusk.png');

        game.load.image('bubble1', 'assets/images/booble1.png');
        game.load.image('bubble2', 'assets/images/booble2.png');

        game.load.audio('music', 'assets/sounds/musicLoop.mp3');
        game.load.audio('pop', 'assets/sounds/sfxPop.mp3');
    },

    create: function() {
        game.add.sprite(0, 0, 'background');

        // --- Burbujas ---
        this.bubbleArray = [];
        for (var i = 0; i < AMOUNT_BUBBLES; i++) {
            var bubble = game.add.sprite(
                game.rnd.integerInRange(1, 1140),
                game.rnd.integerInRange(0, 950),
                'bubble' + game.rnd.integerInRange(1, 2)
            );
            bubble.vel = 0.2 + game.rnd.frac() * 2;
            bubble.alpha = 0.9;
            bubble.scale.setTo(0.2 + game.rnd.frac());
            this.bubbleArray.push(bubble);
        }

        // --- Fauna ---
        this.mollusk = game.add.sprite(500, 150, 'mollusk');
        this.shark = game.add.sprite(500, 20, 'shark');
        this.fishes = game.add.sprite(100, 550, 'fishes');

        // --- Caballito ---
        this.horse = game.add.sprite(game.width / 2, game.height / 2, 'horse');
        this.horse.frame = 0;
        this.horse.anchor.setTo(0.5);

        game.input.onDown.add(this.onTap, this);

        // --- Diamantes (sin encimarse ni tocar al caballito) ---
        this.diamonds = [];
        var rectHorse = this.getBounds(this.horse);
        for (var i = 0; i < AMOUNT_DIAMONDS; i++) {
            var diamond = game.add.sprite(0, 0, 'diamonds');
            diamond.frame = game.rnd.integerInRange(0, 3);
            diamond.scale.setTo(0.30 + game.rnd.frac());
            diamond.anchor.setTo(0.5);
            this.diamonds.push(diamond);

            var tries = 0;
            var rect;
            do {
                diamond.x = game.rnd.integerInRange(50, 1050);
                diamond.y = game.rnd.integerInRange(50, 600);
                rect = this.getBounds(diamond);
                tries++;
            } while (
                tries < MAX_PLACEMENT_TRIES &&
                (this.isOverlappingOtherDiamond(i, rect) || this.isRectanglesOverlapping(rectHorse, rect))
            );
        }

        // --- Pool de explosiones (listener registrado una sola vez) ---
        this.explosionGroup = game.add.group();
        for (var i = 0; i < 10; i++) {
            var explosion = this.explosionGroup.create(100, 100, 'explosion');
            explosion.anchor.setTo(0.5);

            explosion.tweenScale = game.add.tween(explosion.scale).to({
                x: [0.4, 0.8, 0.4],
                y: [0.4, 0.8, 0.4]
            }, 600, Phaser.Easing.Exponential.Out, false, 0, 0, false);

            explosion.tweenAlpha = game.add.tween(explosion).to({
                alpha: [1, 0.6, 0]
            }, 600, Phaser.Easing.Exponential.Out, false, 0, 0, false);

            explosion.tweenAlpha.onComplete.add(function(target) {
                target.kill();
            }, this);

            explosion.kill();
        }

        // --- Sonido ---
        this.sfxPop = game.add.audio('pop', 0.6);
        if (!music) {
            music = game.add.audio('music', 0.4, true);
        }

        // --- HUD ---
        var style = { font: 'bold 30pt Arial', fill: '#FFFFFF', align: 'center' };
        var smallStyle = { font: 'bold 18pt Arial', fill: '#FFFFFF', align: 'left' };

        this.currentScore = 0;
        this.scoreText = game.add.text(game.width / 2, 40, '0', style);
        this.scoreText.anchor.setTo(0.5);

        this.totalTime = GAME_TIME;
        this.timerText = game.add.text(1000, 40, this.totalTime + '', style);
        this.timerText.anchor.setTo(0.5);

        this.highScoreText = game.add.text(20, 20, 'RÉCORD: ' + this.highScore, smallStyle);

        this.startText = game.add.text(game.width / 2, game.height - 80, 'TOCA PARA EMPEZAR', style);
        this.startText.anchor.setTo(0.5);
        game.add.tween(this.startText).to({ alpha: 0.2 }, 700, Phaser.Easing.Sinusoidal.InOut, true, 0, -1, true);

        this.timerGameOver = game.time.events.loop(Phaser.Timer.SECOND, this.tickTimer, this);
    },

    tickTimer: function() {
        if (!this.flagFirstMouseDown || this.endGame) {
            return;
        }
        this.totalTime--;
        this.timerText.text = this.totalTime + '';
        if (this.totalTime <= 10) {
            this.timerText.fill = '#FF5555';
        }
        if (this.totalTime <= 0) {
            this.finishGame(false);
        }
    },

    increaseScore: function() {
        this.countSmile = 0;
        this.horse.frame = 1;
        this.sfxPop.play();

        this.currentScore += POINTS_PER_DIAMOND;
        this.scoreText.text = this.currentScore;

        this.amountDiamondsCaught++;
        if (this.amountDiamondsCaught >= AMOUNT_DIAMONDS) {
            this.currentScore += this.totalTime * POINTS_PER_SECOND_LEFT;
            this.scoreText.text = this.currentScore;
            this.finishGame(true);
        }
    },

    finishGame: function(won) {
        if (this.endGame) {
            return;
        }
        this.endGame = true;
        game.time.events.remove(this.timerGameOver);

        var newRecord = this.currentScore > this.highScore;
        if (newRecord) {
            this.highScore = this.currentScore;
            saveHighScore(this.highScore);
            this.highScoreText.text = 'RÉCORD: ' + this.highScore;
        }

        var msg = won ? '¡GANASTE!' : 'GAME OVER';
        var sub = 'PUNTOS: ' + this.currentScore;
        if (won) {
            sub += '  (bonus ' + this.totalTime + 's)';
        }
        if (newRecord) {
            sub += '\n¡NUEVO RÉCORD!';
        }
        this.showFinalMessage(msg, sub);

        game.time.events.add(Phaser.Timer.SECOND, function() {
            this.canRestart = true;
            this.restartText.visible = true;
        }, this);
    },

    showFinalMessage: function(msg, sub) {
        if (this.tweenMollusk) {
            this.tweenMollusk.stop();
        }

        var bgAlpha = game.add.bitmapData(game.width, game.height);
        bgAlpha.ctx.fillStyle = '#000000';
        bgAlpha.ctx.fillRect(0, 0, game.width, game.height);
        var bg = game.add.sprite(0, 0, bgAlpha);
        bg.alpha = 0.5;

        var bigStyle = { font: 'bold 60pt Arial', fill: '#FFFFFF', align: 'center' };
        var subStyle = { font: 'bold 24pt Arial', fill: '#FFE066', align: 'center' };

        var title = game.add.text(game.width / 2, game.height / 2 - 60, msg, bigStyle);
        title.anchor.setTo(0.5);

        var subtitle = game.add.text(game.width / 2, game.height / 2 + 30, sub, subStyle);
        subtitle.anchor.setTo(0.5, 0);

        this.restartText = game.add.text(game.width / 2, game.height - 60, 'TOCA PARA JUGAR DE NUEVO', subStyle);
        this.restartText.anchor.setTo(0.5);
        this.restartText.visible = false;
    },

    onTap: function() {
        if (this.endGame) {
            if (this.canRestart) {
                game.state.restart();
            }
            return;
        }

        if (!this.flagFirstMouseDown) {
            this.flagFirstMouseDown = true;
            this.startText.visible = false;
            this.tweenMollusk = game.add.tween(this.mollusk.position)
                .to({ y: -0.001 }, 5800, Phaser.Easing.Cubic.InOut, true, 0, -1, true);

            // Los navegadores sólo dejan sonar audio tras una interacción
            if (music && !music.isPlaying) {
                music.play();
            }
        }
    },

    getBounds: function(sprite) {
        return new Phaser.Rectangle(sprite.left, sprite.top, sprite.width, sprite.height);
    },

    // Hitbox más angosta que el sprite para que se sienta justo
    getBoundsHorse: function() {
        var width = Math.abs(this.horse.width) / 2;
        return new Phaser.Rectangle(
            this.horse.x - width / 2,
            this.horse.y - this.horse.height / 2,
            width,
            this.horse.height
        );
    },

    isRectanglesOverlapping: function(r1, r2) {
        if (r1.x > r2.x + r2.width || r2.x > r1.x + r1.width) {
            return false;
        }
        if (r1.y > r2.y + r2.height || r2.y > r1.y + r1.height) {
            return false;
        }
        return true;
    },

    isOverlappingOtherDiamond: function(index, rect) {
        for (var i = 0; i < index; i++) {
            if (this.isRectanglesOverlapping(this.getBounds(this.diamonds[i]), rect)) {
                return true;
            }
        }
        return false;
    },

    update: function() {
        // Factor de tiempo: 1 a 60 FPS, 0.5 a 120 FPS, etc.
        var dt = Math.min(game.time.physicsElapsed * 60, 3);

        // El fondo se anima siempre, aunque no hayas empezado
        for (var i = 0; i < AMOUNT_BUBBLES; i++) {
            var bubble = this.bubbleArray[i];
            bubble.y -= bubble.vel * dt;
            if (bubble.y < -50) {
                bubble.y = 700;
                bubble.x = game.rnd.integerInRange(1, 1140);
            }
        }

        this.shark.x -= 1 * dt;
        if (this.shark.x < -300) {
            this.shark.x = 1300;
        }

        this.fishes.x += 0.3 * dt;
        if (this.fishes.x > 1300) {
            this.fishes.x = -300;
        }

        if (!this.flagFirstMouseDown || this.endGame) {
            return;
        }

        if (this.countSmile >= 0) {
            this.countSmile += dt;
            if (this.countSmile > 50) {
                this.countSmile = -1;
                this.horse.frame = 0;
            }
        }

        var distX = game.input.x - this.horse.x;
        var distY = game.input.y - this.horse.y;

        this.horse.scale.setTo(distX > 0 ? 1 : -1, 1);

        // Lerp independiente de los FPS
        var follow = 1 - Math.pow(1 - HORSE_FOLLOW, dt);
        this.horse.x += distX * follow;
        this.horse.y += distY * follow;

        var rectHorse = this.getBoundsHorse();
        for (var i = 0; i < AMOUNT_DIAMONDS; i++) {
            var diamond = this.diamonds[i];
            if (diamond.visible && this.isRectanglesOverlapping(rectHorse, this.getBounds(diamond))) {
                diamond.visible = false;

                var explosion = this.explosionGroup.getFirstDead();
                if (explosion) {
                    explosion.reset(diamond.x, diamond.y);
                    explosion.tweenScale.start();
                    explosion.tweenAlpha.start();
                }

                this.increaseScore();
                if (this.endGame) {
                    return;
                }
            }
        }
    }
};

var game = new Phaser.Game(1136, 640, Phaser.CANVAS);
game.state.add('gameplay', GamePlayManager);
game.state.start('gameplay');
