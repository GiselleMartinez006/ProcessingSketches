import applet.GuiSketch;
import applet.HotswapGuiSketch;
import processing.core.PGraphics;

public class Ultrasound extends HotswapGuiSketch {
    private float t = 0;
    PGraphics pg;
    private int frameRecordingEnds;
    private boolean keyWasPressed;
    private int recordingFrames = 720;

    public static void main(String[] args) {
        GuiSketch.main("Ultrasound");
    }

    public void settings() {
        size(800, 800, P2D);
    }

    public void setup() {
        surface.setAlwaysOnTop(true);
        pg = createGraphics(width, height, P2D);
    }

    public void draw() {
        t += radians(slider("t",0,1,1));
        pg.beginDraw();
        backgroundPass(t, pg);
        noiseOffsetPass(t, pg);
        pg.endDraw();
        image(pg, 0,0, width, height);
        rec();
        gui();
    }

    private void backgroundPass(float t, PGraphics pg) {
        String background = "ultrasound/background.glsl";
        uniform(background).set("alpha", slider("alpha"));
        uniform(background).set("time", t);
        hotFilter(background, pg);
    }

    private void rec() {
        if (isRecording()) {
            println(frameCount - frameRecordingEnds + recordingFrames + " / " + recordingFrames);
            pg.save(captureDir + frameCount + ".jpg");
        }
    }

    private boolean isRecording() {
        return frameCount < frameRecordingEnds;
    }

    private float recordingTimeNormalized() {
        return norm(frameCount, frameRecordingEnds - recordingFrames, frameRecordingEnds);
    }

    private void screenshot() {
        boolean keyJustReleased = keyWasPressed && !keyPressed;
        keyWasPressed = keyPressed;
        if (keyJustReleased && key == 's') {
            pg.save(captureDir + frameCount + ".jpg");
        }
    }

    public void keyPressed() {
        if (key == 'k') {
            frameRecordingEnds = frameCount + recordingFrames + 1;
        }
        if (key == 'r') {
            frameRecordingEnds = frameCount - 1;
        }
    }
}