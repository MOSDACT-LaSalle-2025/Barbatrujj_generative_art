import ddf.minim.*;
import ddf.minim.analysis.*;
import java.util.ArrayList;
import java.io.File;

// --- Librerías y variables principales ---
Minim minim;
AudioPlayer track;
BeatDetect beat;

// Estado de final
boolean showCongrats = false;
int congratsStart = 0;

// Pong
float y1=370, y2=370;
float ysize1=130, ysize2=130;
float vely1=8, vely2=8;
float ballX, ballY;
float ballDirX = 1, ballDirY = 0;
float ballSpeed = 7;
float ballSize = 20;
boolean moveDown1=false, moveUp1=false, moveDown2=false, moveUp2=false;

// Trail de la pelota
ArrayList<PVector> ballTrail = new ArrayList<PVector>();
float glowHue = 0;

// FFT
FFT fft;
int bands = 256;
float[] spectrum = new float[bands];
float[] sum = new float[bands];
float beatFactor = 1.2;
float unit;
float colorOffset = 0;

// Partículas
ArrayList<Dot> dots = new ArrayList<Dot>();

// Visuales (controles)
boolean showParticles = true;
boolean showFFT = true;
boolean invertColors = false;
boolean blurBackground = false;

// --- Clase Dot ---
class Dot {
  float x, y, baseSize, currentSize, targetSize, noiseOffset, angleFromCenter, distanceFromCenter;
  
  Dot(float x, float y){
    this.x = x; this.y = y;
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
  
  // display ahora usa invertColors global para decidir hue
  void display(float colorOffset){
    float hue = (degrees(angleFromCenter)*3 + frameCount*2 + colorOffset) % 360;
    if(invertColors) hue = (hue + 180) % 360;
    float intensityFactor = random(0.5, 0.8);
    fill(hue, 50 * intensityFactor, 80 * intensityFactor);
    noStroke();
    ellipse(x, y, currentSize, currentSize);
  }
}

// --- Setup & settings ---
void settings(){
  fullScreen();
}

void setup(){
  frameRate(60);
  unit = height/100.0;
  noCursor(); // ocultar ratón

  // Selección aleatoria de audio desde data/audio
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

  ballX = width/2;
  ballY = height/2;
  colorMode(HSB, 360, 100, 100, 255);

  // Crear cuadrícula de partículas (ajusta cols/rows si hace lento)
  int cols = 120;
  int rows = 80;
  float stepX = width / (cols + 1.0);
  float stepY = height / (rows + 1.0);
  for (int i=1; i<=cols; i++){
    for (int j=1; j<=rows; j++){
      dots.add(new Dot(i*stepX, j*stepY));
    }
  }
}

// --- Draw ---
void draw(){
  // Pantalla final
  if(showCongrats){
    background(invertColors ? 255 : 0);
    fill(invertColors ? 0 : 255);
    textAlign(CENTER,CENTER);
    textSize(height/10.0);
    text("CONGRATS\nYOU'VE KEPT THE PACE.", width/2, height/2);
    if(millis() - congratsStart > 3000) exit();
    return;
  }

  // Fondo con blur opcional: en vez de background con alpha usamos rect semitransparente
  if(blurBackground){
    // Dibujamos una capa semitransparente para dejar estela
    noStroke();
    fill(invertColors ? 255 : 0, 30); // si invertido usamos blanco semitransparente
    rect(0,0,width,height);
  } else {
    background(invertColors ? 255 : 0);
  }

  beat.detect(track.mix);
  float intensity = track.mix.level() * 50;

  // Onset -> cambia dirección y color del halo
  if(beat.isOnset()){
    float angle = random(TWO_PI);
    ballDirX = cos(angle);
    ballDirY = sin(angle);
    glowHue = random(0,360);
    for(Dot d : dots) d.react(intensity);
    colorOffset += random(50,100);
  }

  // Partículas (solo si showParticles)
  if(showParticles){
    pushStyle();
    colorMode(HSB, 360, 100, 100, 255);
    for(Dot d : dots){
      d.update(intensity);
      d.display(colorOffset);
    }
    popStyle();
  }

  // FFT central (solo si showFFT)
  if(showFFT){
    fft.forward(track.mix);
    for(int i=0;i<fft.avgSize();i++){
      spectrum[i]=fft.getAvg(i)/2;
      sum[i]+=(abs(spectrum[i])-sum[i])*0.25;
    }
    drawCenter(sum);
  }

  // Pelota y lógica Pong (siempre visible)
  ballX += ballDirX * ballSpeed;
  ballY += ballDirY * ballSpeed;

  // Trail - aplicamos invertColors al color de la trail
  noFill();
  for(int i=0;i<ballTrail.size();i++){
    float alpha = map(i,0,ballTrail.size(),30,180);
    float hueTrail = glowHue;
    if(invertColors) hueTrail = (hueTrail + 180) % 360;
    stroke(hueTrail, 100, invertColors ? 0 : 100, alpha);
    PVector p = ballTrail.get(i);
    float trailSize = map(i,0,ballTrail.size(), ballSize*0.3, ballSize);
    ellipse(p.x, p.y, trailSize, trailSize);
  }

  // Añadir la posición actual a la trail (después de dibujar)
  ballTrail.add(0, new PVector(ballX, ballY));
  if(ballTrail.size() > 30) ballTrail.remove(ballTrail.size()-1);

  // Glow pelota
  float glowSize = ballSize + 20 * track.mix.level();
  float hueGlow = glowHue;
  if(invertColors) hueGlow = (hueGlow + 180) % 360;
  noFill();
  stroke(hueGlow, 100, invertColors ? 0 : 100, 140);
  strokeWeight(2);
  ellipse(ballX, ballY, glowSize, glowSize);

  // Pelota visible: borde rojo fijo (HSB: hue 0)
  // Si invertColors -> usamos negro/tono invertido para rellenar
  if(invertColors) fill(0); else fill(255);
  stroke(0, 100, 100, 200); // borde rojo HSB
  strokeWeight(2);
  ellipse(ballX, ballY, ballSize, ballSize);

  if(ballY < 0 || ballY > height - ballSize) ballDirY *= -1;

  // Barras laterales con glow (glow hue respeta invertColors)
  float barPulse1 = 20 * track.mix.level();
  float barPulse2 = 20 * track.mix.level();
  float barHue = glowHue;
  if(invertColors) barHue = (barHue + 180) % 360;
  color glowColor = color(barHue, 80, invertColors ? 0 : 100, 180);

  for(int g=8; g>0; g--){
    stroke(barHue, 80, invertColors ? 0 : 100, 20 + g*10);
    strokeWeight(1);
    noFill();
    rect(-g/2.0, y1 - barPulse1/2 - g/2.0, 20 + g, ysize1 + barPulse1 + g);
    rect(width - 20 - g/2.0, y2 - barPulse2/2 - g/2.0, 20 + g, ysize2 + barPulse2 + g);
  }
  noStroke();
  fill(invertColors ? 255 : 0); // cuerpo negro o blanco si invertido
  rect(0, y1 - barPulse1/2, 20, ysize1 + barPulse1);
  rect(width-20, y2 - barPulse2/2, 20, ysize2 + barPulse2);

  strokeWeight(1);

  // Colisiones con palas
  if(ballX < 20 && ballY > y1 && ballY < y1 + ysize1){
    ballDirX *= -1; ballDirY *= 1.1; ballX = 20; ysize1 = max(ysize1 - 1, 30);
  }
  if(ballX > width - 20 - ballSize && ballY > y2 && ballY < y2 + ysize2){
    ballDirX *= -1; ballDirY *= 1.1; ballX = width - 20 - ballSize; ysize2 = max(ysize2 - 1, 30);
  }

  // Gol: reset posición y reinicio canción
  if(ballX < 0 || ballX > width){
    ballX = width/2;
    ballY = height/2;
    ballDirX = random(1) < 0.5 ? 1 : -1;
    ballDirY = 0;
    ballTrail.clear();
    if(!showCongrats){
      track.rewind();
      track.play();
    }
  }

  // Movimiento barras
  if(moveDown1 && y1 < height - ysize1) y1 += vely1;
  if(moveUp1 && y1 > 0) y1 -= vely1;
  if(moveDown2 && y2 < height - ysize2) y2 += vely2;
  if(moveUp2 && y2 > 0) y2 -= vely2;

  // Fin de la canción -> pantalla final
  if(!showCongrats && !track.isPlaying()){
    showCongrats = true;
    congratsStart = millis();
  }
}

// --- FFT central ---
void drawCenter(float[] sum){
  int sphereRadius = int(5 * unit);
  for(int angle=0; angle<360; angle++){
    float extRadius = map(noise(angle*0.1, frameCount*0.01), 0, 1, sphereRadius*1.3, sphereRadius*3.5);
    extRadius *= 1 + beatFactor * abs(sum[angle % sum.length]);

    float x0 = cos(radians(angle)) * sphereRadius + width/2;
    float y0 = sin(radians(angle)) * sphereRadius + height/2;
    float xDest = cos(radians(angle)) * extRadius + width/2;
    float yDest = sin(radians(angle)) * extRadius + height/2;

    float hue = (sin(radians(angle*3 + frameCount*2)) * 60 + colorOffset) % 360;
    if(invertColors) hue = (hue + 180) % 360;
    stroke(hue, 80, invertColors ? 0 : 100);
    line(x0, y0, xDest, yDest);
  }
}

// --- Controles ---
void keyPressed(){
  if(key=='l') moveDown1 = true;
  if(key=='p') moveUp1 = true;
  if(key=='l') moveDown2 = true;
  if(key=='p') moveUp2 = true;

  // toggles:
  if (key == '1') showParticles = !showParticles;      // space -> partículas
  if (key == '2') showFFT = !showFFT;            // enter -> FFT
  if (key == ' ') invertColors = !invertColors;        // 1 -> invertir colores
  if (key == '3') blurBackground = !blurBackground;    // 2 -> blur/estela
}

void keyReleased(){
  if(key=='l') moveDown1 = false;
  if(key=='p') moveUp1 = false;
  if(key=='l') moveDown2 = false;
  if(key=='p') moveUp2 = false;
}
