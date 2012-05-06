import ddf.minim.Minim;
import ddf.minim.AudioPlayer;
import processing.video.Capture;
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

Capture capture;
PImage previous;

MultiMarker ar;
int marker;

PFont font;

int offset = 0;
boolean started = false;

int previousPart = -1;

public void setup()
{
  size(864, 486, P3D);
  background(0);
  //smooth();
  frameRate(30);
  hint(ENABLE_DEPTH_TEST);

  bvhs[0] = new PBvh(loadStrings("nocchi.bvh"));
  bvhs[1] = new PBvh(loadStrings("aachan.bvh"));
  bvhs[2] = new PBvh(loadStrings("kashiyuka.bvh"));

  capture = new Capture(this, width, height, 30);
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
  final int realPart = min(millis / PART_LENGTH, PART_WHITE);
  final int part = virtualPart(millis);
  final boolean partChanged = (part != previousPart);

  ar.detect(capture);

  drawBackground(part, capture);

  if(!partChanged && part != PART_WHITE) {
    applyBlur();
  }

  if(ar.isExistMarker(marker)) {
    ar.beginTransform(marker);

    rotateX(HALF_PI);

    pushMatrix();
    scale(0.5, 0.5, 0.5);

    if(part == PART_DISPLAY || part == PART_LASER) {
      drawDisplay();
    }

    if(part >= PART_PLAIN && part <= PART_LASER) {
      drawGround(millis, part == PART_PLAIN);
    }

    if(part == PART_LASER) {
      drawLaser(millis, realPart != PART_LASER);
    }

    drawModels(millis);

    popMatrix();

    ar.endTransform();
  }

  saveScreen(previous);

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

public void captureEvent(Capture c) {
  c.read();
}

private void applyBlur() {
  tint(color(255), 180);
  image(previous, 0, 0);
  noTint();
}

private void drawBackground(int part, PImage image) {
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
}

private void drawDisplay() {
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

private void drawGround(int millis, boolean plain) {
  final int cycle = 60000 / SOUND_BPM;
  pushMatrix();
  scale(30, 0, 30);
  for(int z = -5; z <= 5; ++z) {
    for(int x = -5; x <= 5; ++x) {
      pushMatrix();
      translate(2 * x, 0, 2 * z);
      if(plain) {
        noStroke();
        fill(color(255));
      }
      else {
        if(max(abs(x), abs(z)) == millis % cycle / (cycle / 6)) {
          stroke(color(0));
          fill(color(255), 255);
        }
        else {
          noStroke();
          noFill();
        }
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

private void drawLaser(int millis, boolean extra) {
  final int cycle = 60000 / SOUND_BPM;
  stroke(color(0, 255, 0), 228);
  pushMatrix();
  for(int i = -1; i <= 1; i += 2) {
    pushMatrix();
    translate(i * 200, 0, -500);
    for(int j = 0, n = 16; j < n; ++j) {
      float rad = millis % cycle * (PI / n) / cycle + j * (PI / n);
      if(rad > PI) {
        rad -= PI;
      }
      if(i < 0) {
        rad = PI - rad;
      }
      line(0, 0, 0, 800 * cos(rad), 800 * sin(rad), 2000);
    }
    popMatrix();
  }
  if(extra) {
    for(int i = 0; i < 8; ++i) {
      float rad = random(PI);
      line(0, 800, -500, 400 * cos(rad), 0, 400 * sin(rad));
    }
  }
  popMatrix();
}

private void drawModels(int millis) {
  lights();
  directionalLight(255, 255, 255, 0, -1, 0);

  noStroke();
  pushMatrix();
  scale(-1, 1, -1);
  for(int i = 0; i < 3; ++i) {
    PBvh bvh = bvhs[i];
    int c = COLORS[i];
    int alpha = millis < SOUND_LENGTH ? 255 : 255 - min((millis - SOUND_LENGTH) * 255 / 5000, 255);

    bvh.update(millis);
    if(alpha > 0) {
      bvh.draw(c, alpha);
    }
  }
  popMatrix();

  noLights();
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

private void saveScreen(PImage image) {
  loadPixels();
  image.loadPixels();
  for(int i = 0, n = width * height; i < n; ++i) {
    image.pixels[i] = pixels[i];
  }
  image.updatePixels();
  updatePixels();
}
