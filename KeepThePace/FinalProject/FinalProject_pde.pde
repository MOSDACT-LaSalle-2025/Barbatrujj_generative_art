import ddf.minim.*;
import ddf.minim.analysis.*;
import java.util.ArrayList;
import java.io.File;

// ------------------------------------------------------
// VARIABLES GLOBALS 
// ------------------------------------------------------

// Audio & Beat
Minim minim;
AudioPlayer track;
BeatDetect beat;
FFT fft;
int bands = 256;
float[] spectrum = new float[bands];
float[] sum = new float[bands];

// Diferents pantalles
boolean showCongrats = false;   // pantalla final
int congratsStart = 0;          // temos per la pantalla final

// Variables per les barres i la pilota del ping pong
float y1 = 370, y2 = 370;        
float ysize1 = 130, ysize2 = 130;
float vely1 = 8, vely2 = 8;
float ballX, ballY;              
float ballDirX = 1, ballDirY = 0;
float ballSpeed = 8;
float ballSize = 20;
boolean moveDown1 = false, moveUp1 = false;
boolean moveDown2 = false, moveUp2 = false;

// Estela de la pilota 
ArrayList<PVector> ballTrail = new ArrayList<PVector>();
float glowHue = 0;               // Valor aleatori que canvia el color segons el beat

// Variables pels visuals
float beatFactor = 1.2;
float unit;
float colorOffset = 0;
ArrayList<Dot> dots = new ArrayList<Dot>();

// ------------------------------------------------------
// === CLASES ===
// ------------------------------------------------------
class Dot {
  float x, y;
  float baseSize;
  float currentSize;
  float targetSize;
  float noiseOffset;
  float angleFromCenter;
  float distanceFromCenter;
  
  Dot(float x, float y){
    this.x = x;
    this.y = y;
    baseSize = random(0.2, 0.7);
    currentSize = baseSize;
    targetSize = baseSize;
    noiseOffset = random(1000);
    angleFromCenter = atan2(y - height/2, x - width/2);
    distanceFromCenter = dist(x, y, width/2, height/2);
  }
  
  void update(float beatIntensity){
    currentSize = lerp(currentSize, targetSize, 0.1);
    float wave = noise(noiseOffset + frameCount*0.01) * 0.3;
    float pulse = sin(frameCount*0.05 - distanceFromCenter*0.05) * 0.3 * beatIntensity;
    currentSize = baseSize + wave + pulse;
  }
  
  void react(float intensity){
    targetSize = baseSize + random(0, intensity * 0.1);
  }
  
  void display(float colorOffset){
    float hue = (degrees(angleFromCenter) * 3 + frameCount*2 + colorOffset) % 360;
    float intensityFactor = random(0.5, 0.8);
    fill(hue, 50 * intensityFactor, 80 * intensityFactor);
    noStroke();
    ellipse(x, y, currentSize, currentSize);
  }
}


void settings(){
  fullScreen();
}

void setup(){
  frameRate(60);
  unit = height / 100.0;

  // Carregar l'audio aleatori de la carpeta
  String audioFolder = sketchPath("data/audio");
  File folder = new File(audioFolder);
  File[] list = folder.listFiles((dir, name) -> name.toLowerCase().endsWith(".mp3"));
  if (list == null || list.length == 0) {
    println("No hay archivos MP3 en data/audio");
    exit();
  }
  int randomIndex = int(random(list.length));
  String chosen = "audio/" + list[randomIndex].getName();
  println("Reproduciendo: " + chosen);

  minim = new Minim(this);
  track = minim.loadFile(chosen);
  track.play();
  
  beat = new BeatDetect();
  beat.setSensitivity(300);

  fft = new FFT(track.bufferSize(), track.sampleRate());
  fft.linAverages(bands);

  ballX = width / 2;
  ballY = height / 2;
  colorMode(HSB, 360, 100, 100, 255);

  // Crear cuadrícula de partícules 
  int cols = 120;
  int rows = 80;
  float stepX = width / (cols + 1.0);
  float stepY = height / (rows + 1.0);
  for (int i = 1; i <= cols; i++){
    for (int j = 1; j <= rows; j++){
      dots.add(new Dot(i * stepX, j * stepY));
    }
  }
}


void draw(){
  // Pantalla final que apareix al final del joc
  if (showCongrats) {
    background(0);
    fill(0, 0, 100);
    textAlign(CENTER, CENTER);
    textSize(height / 10.0);
    text("CONGRATS\nYOU'VE KEPT THE PACE.", width / 2, height / 2);
    if (millis() - congratsStart > 3000) exit();
    return;
  }
  //Setup del fons i de les partícules
  background(0);
  beat.detect(track.mix);
  float intensity = track.mix.level() * 50;

  if (beat.isOnset()) {
    float angle = random(TWO_PI);
    ballDirX = cos(angle);
    ballDirY = sin(angle);
    glowHue = random(0, 360);
    for (Dot d : dots) d.react(intensity);
    colorOffset += random(50, 100);
  }

  // Partícules
  for (Dot d : dots) {
    d.update(intensity);
    d.display(colorOffset);
  }

  // FFT del cercle central
  fft.forward(track.mix);
  for (int i = 0; i < fft.avgSize(); i++) {
    spectrum[i] = fft.getAvg(i) / 2;
    sum[i] += (abs(spectrum[i]) - sum[i]) * 0.25;
  }
  drawCenter(sum);

  // Moviment de la pilota pelota
  ballX += ballDirX * ballSpeed;
  ballY += ballDirY * ballSpeed;

  // Estetica de la pilota i de la estela
  ballTrail.add(new PVector(ballX, ballY));
  if (ballTrail.size() > 30) ballTrail.remove(0);
  
  // Configuració de la estela
  noFill();
  for (int i = 0; i < ballTrail.size(); i++) {
    float alpha = map(i, 0, ballTrail.size(), 50, 200);
    stroke(glowHue, 100, 100, alpha);
    ellipse(ballTrail.get(i).x, ballTrail.get(i).y, ballSize, ballSize);
  }
  //Configuració del glow de la pilota
  float glowSize = ballSize + 20 * track.mix.level();
  noFill();
  stroke(glowHue, 100, 100, 120);
  ellipse(ballX, ballY, glowSize, glowSize);
  
  // Configuració de la pilota en si
  fill(255);
  stroke(0, 100, 100, 120);
  strokeWeight(1);
  ellipse(ballX, ballY, ballSize, ballSize);

  if (ballY < 0 || ballY > height - ballSize) ballDirY *= -1;

  // Barras amb glow
  float barPulse1 = 20 * track.mix.level();
  float barPulse2 = 20 * track.mix.level();
  color glowColor = color(180, 100, 100, 180);

  // Barra esquerra
  for (int g = 8; g > 0; g--) {
    stroke(glowColor, g * 20);
    strokeWeight(1);
    noFill();
    rect(0 - g / 2.0, y1 - barPulse1 / 2 - g / 2.0, 20 + g, ysize1 + barPulse1 + g);
  }
  noStroke();
  fill(0);
  rect(0, y1 - barPulse1 / 2, 20, ysize1 + barPulse1);

  // Barra dreta
  for (int g = 8; g > 0; g--) {
    stroke(glowColor, g * 20);
    strokeWeight(1);
    noFill();
    rect(width - 20 - g / 2.0, y2 - barPulse2 / 2 - g / 2.0, 20 + g, ysize2 + barPulse2 + g);
  }
  noStroke();
  fill(0);
  rect(width - 20, y2 - barPulse2 / 2, 20, ysize2 + barPulse2);

  strokeWeight(1);

  // Control de rebots a les barres
  if (ballX < 20 && ballY > y1 && ballY < y1 + ysize1) {
    ballDirX *= -1;
    ballDirY *= 1.1;
    ballX = 20;
    ysize1 = max(ysize1 - 1, 30);
  }
  if (ballX > width - 20 - ballSize && ballY > y2 && ballY < y2 + ysize2) {
    ballDirX *= -1;
    ballDirY *= 1.1;
    ballX = width - 20 - ballSize;
    ysize2 = max(ysize2 - 1, 30);
  }

  // Quan la pilota toca la dreta o la esquerra de la pantalla, es reinicia la cançó
  if (ballX < 0 || ballX > width) {
    ballX = width / 2;
    ballY = height / 2;
    ballDirX = random(1) < 0.5 ? 1 : -1;
    ballDirY = 0;
    ballTrail.clear();
    if (!showCongrats) {
      track.rewind();
      track.play();
    }
  }

  // Moviment de les barres
  if (moveDown1 && y1 < height - ysize1) y1 += vely1;
  if (moveUp1 && y1 > 0) y1 -= vely1;
  if (moveDown2 && y2 < height - ysize2) y2 += vely2;
  if (moveUp2 && y2 > 0) y2 -= vely2;

  // Final de la cançó
  if (!showCongrats && !track.isPlaying()) {
    showCongrats = true;
    congratsStart = millis();
  }
}

// Funció pels visuals del cercle central. Hi ha varios patrons de colors que canvien aleatoriament amb el beat. El cercle està envoltat d'una fft que llegeix la cançó.
void drawCenter(float[] sum){
  int sphereRadius = int(5 * unit);
  for (int angle = 0; angle < 360; angle++) {
    float extRadius = map(noise(angle * 0.1, frameCount * 0.01), 0, 1,
                          sphereRadius * 1.3, sphereRadius * 3.5);
    extRadius *= 1 + beatFactor * abs(sum[angle % sum.length]);

    float x0 = cos(radians(angle)) * sphereRadius + width / 2;
    float y0 = sin(radians(angle)) * sphereRadius + height / 2;
    float xDest = cos(radians(angle)) * extRadius + width / 2;
    float yDest = sin(radians(angle)) * extRadius + height / 2;

    float hue = (sin(radians(angle * 3 + frameCount * 2)) * 60 + colorOffset) % 360;
    stroke(hue, 80, 100);
    line(x0, y0, xDest, yDest);
  }
}

// Controls del teclat
void keyPressed(){
  if (key == 's') moveDown1 = true;
  if (key == 'w') moveUp1 = true;
  if (key == 'l') moveDown2 = true;
  if (key == 'o') moveUp2 = true;
}

void keyReleased(){
  if (key == 's') moveDown1 = false;
  if (key == 'w') moveUp1 = false;
  if (key == 'l') moveDown2 = false;
  if (key == 'o') moveUp2 = false;
}
