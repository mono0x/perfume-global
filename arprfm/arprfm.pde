import processing.opengl.*;
import ddf.minim.Minim;
import ddf.minim.AudioPlayer;
import JMyron.JMyron;
import jp.nyatla.nyar4psg.MultiMarker;

final int SOUND_BPM    = 130;
final int SOUND_LENGTH = 64247;
final int PART_LENGTH  = (60000 * 4 * 4 / SOUND_BPM);
final int MAX_PARTS    = SOUND_LENGTH / PART_LENGTH;
final int CELL_SIZE    = 64;

final int PART_NORMAL  = 0;
final int PART_INVERT  = 1;
final int PART_MOSAIC  = 2;
final int PART_PLAIN   = 3;
final int PART_GROUND  = 4;
final int PART_DISPLAY = 5;
final int PART_LASER   = 6;
final int PART_MIX     = 7;
final int PART_WHITE   = 8;

BvhParser parserA = new BvhParser();
PBvh[] bvhs = new PBvh[3];

final int[] COLORS = new int[] {
  color(255, 255, 40),
  color(220, 40, 255),
  color(255, 120, 160),
};

boolean debug = false;

Minim minim;
AudioPlayer player;

JMyron capture;
PImage image;

PImage previous;

MultiMarker ar;
int marker;

PFont font;

int offset = 0;
boolean started = false;

int previousPart = -1;

public void setup()
{
  size(640, 480, P3D);
  background(0);
  //smooth();
  frameRate(30);
  hint(ENABLE_DEPTH_TEST);

  bvhs[0] = new PBvh(loadStrings("nocchi.bvh"));
  bvhs[1] = new PBvh(loadStrings("aachan.bvh"));
  bvhs[2] = new PBvh(loadStrings("kashiyuka.bvh"));

  capture = new JMyron();
  image = new PImage(width, height, RGB);
  capture.start(width, height);
  capture.findGlobs(0);

  previous = new PImage(width, height, RGB);

  ar = new MultiMarker(this, width, height, "camera_para.dat", NyAR4PsgConfig.CONFIG_PSG);
  marker = ar.addARMarker(loadImage("marker.png"), 16, 25, 80);

  font = loadFont("Meiryo-24.vlw");

  minim = new Minim(this);
  player = minim.loadFile("Perfume_globalsite_sound.wav");

  loop();
}

public void draw() {
  if(millis() < 1000) {
    return;
  }
  else if(!started && !player.isPlaying()) {
    player.play();
    offset = millis();
    started = true;
  }

  final int millis = millis() - offset;
  final int part = virtualPart(millis);
  final boolean partChanged = (part != previousPart);

  capture.update();

  image.loadPixels();
  capture.imageCopy(image.pixels);
  image.updatePixels();

  ar.detect(image);

  if(part == PART_INVERT) {
    background(255);
    image(image, 0, 0);
    filter(INVERT);
  }
  else if(part == PART_MOSAIC) {
    background(255);
    loadPixels();
    image.loadPixels();
    for(int y = 0; y < height / 16; ++y) {
      for(int x = 0; x < width / 16; ++x) {
        int c = image.pixels[(x * 16 + floor(random(16))) + (y * 16 + floor(random(16))) * width];
        c = color(red(c) + random(20) - 10, green(c) + random(20) - 10, blue(c) + random(20) - 10);
        if(random(1000) < 1) {
          c = blendColor(color(255), c, SUBTRACT);
        }
        fill(c);
        rect(x * 16, y * 16, 16, 16);
      }
    }
    image.updatePixels();
    updatePixels();
  }
  else if(part == PART_PLAIN) {
    background(0);
  }
  else if(part == PART_LASER) {
    background(0);
    image(image, 0, 0);
    fill(color(0), 128);
    rect(0, 0, width, height);
  }
  else if(part == PART_WHITE) {
    background(255);
  }
  else {
    // basic
    background(255);
    image(image, 0, 0);
  }

  if(!partChanged && part != PART_WHITE) {
    // blur
    tint(color(255), 180);
    image(previous, 0, 0);
    noTint();
  }

  if(ar.isExistMarker(marker)) {
    ar.beginTransform(marker);

    rotateX(HALF_PI);

    pushMatrix();
    scale(0.5, 0.5, 0.5);

    if(part == PART_DISPLAY || part == PART_LASER) {
      // display
      for(int i = -1; i <= 1; ++i) {
        pushMatrix();
        translate(400 * i, 200, -400 + abs(i) * 200);
        rotateY(-i * 0.25 * PI);
        scale(200, 150, 0);
        tint(color(192), 255);
        beginShape();
        texture(previous);
        vertex(-1,  1, 0, width,      0);
        vertex( 1,  1, 0,     0,      0);
        vertex( 1, -1, 0,     0, height);
        vertex(-1, -1, 0, width, height);
        endShape();
        noTint();
        popMatrix();
      }
    }

    if(part >= PART_PLAIN && part <= PART_LASER) {
      // ground
      pushMatrix();
      scale(30, 0, 30);
      for(int z = -5; z <= 5; ++z) {
        for(int x = -5; x <= 5; ++x) {
          pushMatrix();
          translate(2 * x, 0, 2 * z);
          int i = 4 - (max(abs(x), abs(z)) + millis / 100) % 5;
          if(part == PART_PLAIN) {
            fill(color(255));
          }
          else {
            fill(i % 2 == 0 ? COLORS[i / 2] : color(255), 192);
          }
          beginShape();
          vertex(-1, 0, -1);
          vertex( 1, 0, -1);
          vertex( 1, 0,  1);
          vertex(-1, 0,  1);
          endShape();
          popMatrix();
        }
      }
      popMatrix();
    }

    if(part == PART_LASER) {
      pushMatrix();
      for(int i = -1; i <= 1; i += 2) {
        pushMatrix();
        stroke(color(0, 255, 0), 228);
        translate(i * 200, 0, -500);
        for(int j = 0; j < 10; ++j) {
          float rad = millis % 100 * (PI / 10) / 100 + j * (PI / 10);
          line(0, 0, 0, cos(rad) * 800, sin(rad) * 800, 2000);
        }
        popMatrix();
      }
      popMatrix();
    }

    lights();
    directionalLight(255, 255, 255, 0, -1, 0);

    noStroke();
    pushMatrix();
    scale(-1, 1, -1);
    for(int i = 0; i < 3; ++i) {
      PBvh bvh = bvhs[i];
      int c = COLORS[i];
      int alpha = millis < SOUND_LENGTH ? 255 : 255 - min((millis - SOUND_LENGTH) / 8, 255);

      bvh.update(millis);
      if(alpha > 0) {
        bvh.draw(c, alpha);
      }
    }
    popMatrix();

    popMatrix();

    ar.endTransform();
  }

  loadPixels();
  previous.loadPixels();
  for(int i = 0, n = width * height; i < n; ++i) {
    previous.pixels[i] = pixels[i];
  }
  previous.updatePixels();
  updatePixels();

  textFont(font, 24);
  if(debug) {
    debugText("FPS:" + round(frameRate), 4, 28);
    debugText("POS:" + millis, 4, 56);
    debugText("PART:" + part, 4, 84);
  }

  previousPart = part;
}

public void keyPressed() {
  if(key == 'd') {
    debug = !debug;
  }
  else if(key >= '1' && key <= '1' + PART_WHITE) {
    int pos = (key - '1') * PART_LENGTH;
    if(!player.isPlaying()) {
      player.play();
    }
    player.cue(pos);
    offset = millis() - pos;
  }
}

public void stop() {
  capture.stop();
  super.stop();
}

private int virtualPart(int millis) {
  int part = min(millis / PART_LENGTH, PART_WHITE);
  if(part != PART_MIX) {
    return part;
  }
  float p = (float)(millis - PART_MIX * PART_LENGTH) / PART_LENGTH;
  if(p <= 0.5) {
    return PART_LASER;
  }
  part = floor((p - 0.5) / 0.5 * MAX_PARTS);
  if(part == PART_MIX) {
    return PART_WHITE;
  }
  return part;
}

private void invertRect(int[] p, int x, int y, int w, int h) {
  for(int i = 0; i < h; ++i) {
    int index = x + (y + i) * width;
    for(int j = 0; j < w; ++j) {
      p[index] = blendColor(color(255), p[index], SUBTRACT);
      ++index;
    }
  }
}

private void debugText(String text, int x, int y) {
  fill(color(0));
  for(int dy = -1; dy <= 1; ++dy) {
    for(int dx = -1; dx <= 1; ++dx) {
      if(dx == 0 && dy == 0) {
        continue;
      }
      text(text, x + dx, y + dy);
    }
  }
  fill(color(255));
  text(text, x, y);
}
