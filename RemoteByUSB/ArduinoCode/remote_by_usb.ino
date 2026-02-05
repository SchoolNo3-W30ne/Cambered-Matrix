#include "MatrixMini.h"

int speed = 100;

void setup()
{
    Mini.begin(LI_2, 0, 9600);
    Serial.begin(9600);

    Mini.I2C1.MXctrl.motorSet(1, 0);
    Mini.I2C1.MXctrl.motorSet(2, 0);

    Serial.println("MatrixMini готов!");
}

void loop()
{
    if (Serial.available() > 0)
    {
        String cmd = Serial.readStringUntil('\n');
        cmd.trim();

        if (cmd.startsWith("m1 "))
        {
            int m1_speed = parseMotorValue(cmd, "m1");
            int m2_speed = parseMotorValue(cmd, "m2");

            Mini.I2C1.MXctrl.motorSet(1, m1_speed);
            Mini.I2C1.MXctrl.motorSet(2, m2_speed);

            Serial.print("M1:");
            Serial.print(m1_speed);
            Serial.print(" M2:");
            Serial.println(m2_speed);
        }
        else if (cmd == "stop")
        {
            Mini.I2C1.MXctrl.motorSet(1, 0);
            Mini.I2C1.MXctrl.motorSet(2, 0);
            Serial.println("STOP");
        }
        else if (cmd.startsWith("speed "))
        {
            speed = cmd.substring(6).toInt();
            speed = constrain(speed, 0, 100);
            Serial.print("Скорость:");
            Serial.println(speed);
        }
    }

    delay(10);
}

int parseMotorValue(String cmd, String motor)
{
    int idx = cmd.indexOf(motor);
    if (idx == -1)
        return 0;

    int start = idx + motor.length() + 1;
    int end = cmd.indexOf("m", start);
    if (end == -1)
        end = cmd.length();

    String value = cmd.substring(start, end);
    value.trim();
    return constrain(value.toInt(), -100, 100);
}
