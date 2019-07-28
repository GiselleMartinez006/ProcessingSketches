package applet;

import processing.core.PApplet;

import java.util.ArrayList;

public class CustomPApplet extends PApplet {
    protected String name = this.toString().split("@")[0];
    protected String id = name + "_" + year() + nf(month(), 2) + nf(day(), 2) + "-" + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
    protected String captureDir = "out/capture/" + id + "/";

    private ArrayList<Slider> sliders = new ArrayList<Slider>();

    public void draw() {
        surface.setTitle(name + " " + floor(frameRate));
    }

    public float slider(String name, float min, float max) {
        float range = max - min;
        return slider(name, min, max, min + range / 2);
    }

    public float slider(String name, float min, float max, float defaultValue) {
        hint(DISABLE_DEPTH_TEST);
        pushMatrix();
        pushStyle();
        colorMode(RGB, 255, 255, 255, 255);
        Slider slider = null;
        /*try to find slider with this name in known sliders*/
        for (Slider s : sliders) {
            if (s.name.equals(name)) {
                slider = s;
                break;
            }
        }
        if (slider == null) {
            /*slider with this name does not exist yet, let's create it*/
            Slider s = new Slider();
            s.name = name;
            s.min = min;
            s.max = max;
            s.value = defaultValue;
            sliders.add(s);
            slider = s;
        }

        /* find the alpha for automatic fadeout */
        int lastInteractedWithAny = -1;
        int fadeoutDuration = 60;
        int fadeoutDelay = 60 * 2;
        for (Slider s : sliders) {
            if (s.lastInteractedWith > lastInteractedWithAny) {
                lastInteractedWithAny = s.lastInteractedWith;
            }
        }
        float alpha = 255 - map(frameCount, lastInteractedWithAny + fadeoutDelay, lastInteractedWithAny + fadeoutDelay + fadeoutDuration, 0, 255);
        alpha = constrain(alpha, 0, 255);

        /* draw slider */
        int index = sliders.indexOf(slider);
        int sliderHeight = height / 12;
        int sliderWidth = width / 4;
        int sliderLeftX = 40;
        int sliderTopY = 40 + index * floor(sliderHeight + sliderHeight * .2f);
        noFill();
        strokeCap(PROJECT);
        strokeWeight(1);
        stroke(150, alpha);
        rectMode(CORNER);
        float sliderY = sliderTopY + sliderHeight * .5f;
        line(sliderLeftX, sliderY, sliderLeftX + sliderWidth, sliderY);
        float valueX = map(slider.value, slider.min, slider.max, sliderLeftX, sliderLeftX + sliderWidth);

        /* draw selection bar */
        strokeWeight(5);
        stroke(150, alpha);
        float extraSensitivity = 20;
        if (mousePressed) {
            slider.lastInteractedWith = frameCount;
        }
        if (isPointInRect(mouseX, mouseY, sliderLeftX - extraSensitivity, sliderTopY, sliderWidth + extraSensitivity * 2, sliderHeight)) {
            slider.lastInteractedWith = frameCount;
            if (mousePressed) {
                stroke(150, alpha);
                slider.value = map(mouseX, sliderLeftX, sliderLeftX + sliderWidth, slider.min, slider.max);
                slider.value = constrain(slider.value, slider.min, slider.max);
            }
        }
        line(valueX, sliderTopY, valueX, sliderTopY + sliderHeight * .6f);

        /* text info */
        /* resize name to fit slider */
        float defaultTextSize = sliderHeight * .3f;
        float textWidth = sliderWidth * 2;
        float textSize = defaultTextSize;
        while (textWidth > sliderWidth * .6) {
            textSize(textSize -= .5);
            textWidth = textWidth(name);
        }
        fill(150, alpha);
        textAlign(LEFT, CENTER);
        int textOffset = 5;

        text(name, sliderLeftX + textOffset, sliderTopY + sliderHeight * .25f);
        textAlign(RIGHT, CENTER);
        textSize(defaultTextSize);

        /* disregard values after floating point if value > floorBoundary */
        int floorBoundary = 10;
        String humanReadableValue = "";
        if (abs(slider.value) < floorBoundary) {
            humanReadableValue = nf(slider.value, 0, 0);
        } else {
            humanReadableValue = String.valueOf(round(slider.value));
        }
        text(humanReadableValue, sliderLeftX + sliderWidth - textOffset, sliderTopY + sliderHeight * .25f);
        popStyle();
        popMatrix();
        hint(ENABLE_DEPTH_TEST);
        return slider.value;
    }

    private boolean isPointInRect(float px, float py, float rx, float ry, float rw, float rh) {
        return px >= rx && px <= rx + rw && py >= ry && py <= ry + rh;
    }

    private class Slider {
        String name;
        float value;
        float min;
        float max;
        float defaultValue;
        int lastInteractedWith = -1;
    }
}
