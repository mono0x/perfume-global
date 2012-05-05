
// 0:normal
// 1:invert
// 2:mosaic
// 3:normal
// 4:plain
// 5:ground
// 6:display
// 7:fade

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
  marker = ar.addARMarker(loadImage("marker.png"), 320, 320, 80);

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
  float beat = (float)(millis % (60000 / SOUND_BPM)) / (60000 / SOUND_BPM);

  final int part = millis / PART_LENGTH;
  final boolean partChanged = (part != previousPart);

  float partPosition = (float)(millis - PART_LENGTH * part) / PART_LENGTH;

  capture.update();

  image.loadPixels();
  capture.imageCopy(image.pixels);
  image.updatePixels();

  ar.detect(image);

  if(part == 1) {
    // invert
    background(255);
    image(image, 0, 0);
    filter(INVERT);
  }
  else if(part == 2) {
    // mosaic
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
  else if(part == 4) {
    background(0);
  }
  else if(part >= MAX_PARTS) {
    background(255);
  }
  else {
    // basic
    background(255);
    image(image, 0, 0);
  }

  if(!partChanged && part < MAX_PARTS) {
    // blur
    tint(color(255), part < 7 ? 180 : 180 * (1 - partPosition));
    image(previous, 0, 0);
    noTint();
  }

  if(ar.isExistMarker(marker)) {
    ar.beginTransform(marker);

    rotateX(HALF_PI);

    pushMatrix();
    scale(0.5, 0.5, 0.5);

    if(part == 6 || part == 7) {
      // display
      for(int i = -1; i <= 1; ++i) {
        pushMatrix();
        translate(400 * i, 200, -400 + abs(i) * 200);
        rotateY(-i * 0.25 * PI);
        scale(200, 150, 0);
        tint(color(192), part == 6 ? 255 : 255 * (1 - partPosition));
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

    if(part >= 4 && part < MAX_PARTS) {
      // ground
      pushMatrix();
      scale(30, 0, 30);
      for(int z = -5; z <= 5; ++z) {
        for(int x = -5; x <= 5; ++x) {
          pushMatrix();
          translate(2 * x, 0, 2 * z);
          int i = 4 - (max(abs(x), abs(z)) + millis / 100) % 5;
          if(part == 4) {
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

    lights();
    directionalLight(255, 255, 255, 0, -1, 0);

    pushMatrix();
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

  if(part == 7) {
    // fade
    fill(color(255), 255 * partPosition);
    rect(0, 0, width, height);
  }

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
}

public void stop() {
  capture.stop();
  super.stop();
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
