#define LGFX_WT32_SC01
#define LGFX_USE_V1

//#include <Arduino.h>
#include <lvgl.h>
#include <LovyanGFX.hpp>
#include <LGFX_AUTODETECT.hpp>  
#include <Adafruit_MLX90614.h>
#include <Firebase_ESP_Client.h>
#include <DNSServer.h>
#include <NTPClient.h>
//#include <WiFiUdp.h>
//#include <WiFi.h>
#include <WiFiManager.h>

#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// PINOUT --------------------------------------------------------------------------------------------------------
#define LDR_OUT_PIN             34
#define BAT_SENSE_PIN           33
#define BUZZER_PIN              12
#define I2C_SDA_PIN             18
#define I2C_SCL_PIN             19             
// ---------------------------------------------------------------------------------------------------------------

// PARAMS --------------------------------------------------------------------------------------------------------
#define API_KEY         "AIzaSyDWDO49h5s6NYkaw2kjl-XN9trCzjKrnSM"
#define DATABASE_URL    "https://lux-meter-device-default-rtdb.asia-southeast1.firebasedatabase.app/"
#define PROJECT_ID      "lux-meter-device"

// #define screenWidth 480
// #define screenHeight 320
#define screenWidth               320
#define screenHeight              480
#define BATT_SAMPLES              50
// ---------------------------------------------------------------------------------------------------------------

// Define NTP Client to get time
WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "asia.pool.ntp.org");

static LGFX display;
TwoWire I2CMLX = TwoWire(1);
Adafruit_MLX90614 mlx = Adafruit_MLX90614();
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

int _ldrOut, _tempOut;
//int timestamp;  // Variable to save current epoch time
bool hold, saveFlag, signupOK = false;
unsigned long prevMillis, timestamp;
int _luxMax, _luxMin, _tempMax, _tempMin;
int _battPercent;
int _lowestBatt = 100;
float _battVoltage;
double m_cal, b_cal;

/*** Setup screen resolution for LVGL ***/
static lv_disp_draw_buf_t draw_buf;
static lv_color_t buf[screenWidth * 10];
static int32_t x, y;
lv_obj_t *lux_label;
lv_obj_t *temp_label;
lv_obj_t *batt_label;
static lv_style_t genStyle;

/*** Function declaration ***/
void display_flush(lv_disp_drv_t *disp, const lv_area_t *area, lv_color_t *color_p);
void touchpad_read(lv_indev_drv_t *indev_driver, lv_indev_data_t *data);
void lv_button_demo(void);

unsigned long getTime() {
  timeClient.update();
  unsigned long now = timeClient.getEpochTime();
  return now;
}


void setup(void)
{
  Serial.begin(115200);
  I2CMLX.begin(I2C_SDA_PIN, I2C_SCL_PIN);
  display.begin();
  lv_init();


  pinMode(BUZZER_PIN, OUTPUT);

  if (!mlx.begin(MLX90614_I2CADDR, &I2CMLX)) {
    Serial.println("Error connecting to MLX sensor. Check wiring.");
    while (1);
  };

  static lv_style_t style;
  lv_style_init(&genStyle);
  lv_style_init(&style);
  lv_style_set_text_font(&genStyle, &lv_font_montserrat_14);
  lv_style_set_text_font(&style, &lv_font_montserrat_32);

  /* LVGL : Setting up buffer to use for display */
  lv_disp_draw_buf_init(&draw_buf, buf, NULL, screenWidth * 10);

  /*** LVGL : Setup & Initialize the display device driver ***/
  static lv_disp_drv_t disp_drv;
  lv_disp_drv_init(&disp_drv);
  disp_drv.hor_res = screenWidth;
  disp_drv.ver_res = screenHeight;
  disp_drv.flush_cb = display_flush;
  disp_drv.draw_buf = &draw_buf;
  lv_disp_drv_register(&disp_drv);

  
  /*** LVGL : Setup & Initialize the input device driver ***/
  static lv_indev_drv_t indev_drv;
  lv_indev_drv_init(&indev_drv);
  indev_drv.type = LV_INDEV_TYPE_POINTER;
  indev_drv.read_cb = touchpad_read;
  lv_indev_drv_register(&indev_drv);

  display.setTextSize((std::max(display.width(), display.height()) + 255) >> 8);
  display.setTextDatum(textdatum_t::middle_center);
  display.drawString("Connecting...", display.width() / 2,  display.height() / 2);

  delay(1000);

  // WIFI - FIREBASE -------------------------------------------------------------
  WiFiManager wifiManager;
  wifiManager.autoConnect("LUX Monitoring Device");

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  /* Sign up */
  if (Firebase.signUp(&config, &auth, "", "")){
    Serial.println("ok");
    signupOK = true;
  }
  else{
    Serial.printf("%s\n", config.signer.signupError.message.c_str());
  }

  config.token_status_callback = tokenStatusCallback; 
  
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  // ------------------------------------------------------------------------------
  display.clear();

  /*** Create simple label and show LVGL version ***/
  String LVGL_Arduino = "LUX Meter Device";
  lv_obj_t *label = lv_label_create(lv_scr_act());
  lv_label_set_text(label, LVGL_Arduino.c_str());  // set label text
  lv_obj_align(label, LV_ALIGN_TOP_MID, 0, 20);      // Center but 20 from the top
  lv_obj_add_style(label, &genStyle, 0);

  //LUX Label
  lux_label = lv_label_create(lv_scr_act()); // full screen as the parent
  lv_label_set_text(lux_label, " ");  // set label text
  lv_obj_align(lux_label, LV_ALIGN_CENTER, 0, -10);      // Center but 20 from the top
  lv_obj_add_style(lux_label, &style, 0);

  //Temp Label
  temp_label = lv_label_create(lv_scr_act()); // full screen as the parent
  lv_label_set_text(temp_label, " ");  // set label text
  lv_obj_align(temp_label, LV_ALIGN_CENTER, 0, 20);      // Center but 20 from the top
  lv_obj_add_style(temp_label, &style, 0);

  //Battery percent
  batt_label = lv_label_create(lv_scr_act()); // full screen as the parent
  lv_label_set_text(batt_label, " ");  // set label text
  lv_obj_align(batt_label, LV_ALIGN_TOP_RIGHT, -10, 10);      
  lv_obj_add_style(batt_label, &genStyle, 0);
  
  lv_button_demo();

  timeClient.begin();
  timeClient.setTimeOffset(28800);

  //test buzzer
  digitalWrite(BUZZER_PIN, HIGH);
  delay(500);
  digitalWrite(BUZZER_PIN, LOW);
}

void loop(void){
  lv_timer_handler();

  for(int i = 0; i < BATT_SAMPLES; i++){
    _battPercent += analogRead(BAT_SENSE_PIN);
  }

  _battPercent /= BATT_SAMPLES;
  _battPercent = map(_battPercent, 3000, 4095, 0, 100);
  if(_battPercent < 0) _battPercent = 0;
  if(_battPercent < _lowestBatt) _lowestBatt = _battPercent;
  _battPercent = _lowestBatt;
  
  
  if(millis() - prevMillis > 1000 || prevMillis == 0 && Firebase.ready() && signupOK){
    if(Firebase.RTDB.getInt(&fbdo, "device-params/max_lux", &_luxMax)); else Serial.println("FAILED: " + fbdo.errorReason());
    if(Firebase.RTDB.getInt(&fbdo, "device-params/min_lux", &_luxMin)); else Serial.println("FAILED: " + fbdo.errorReason());  
    if(Firebase.RTDB.getInt(&fbdo, "device-params/max_temp", &_tempMax)); else Serial.println("FAILED: " + fbdo.errorReason());
    if(Firebase.RTDB.getInt(&fbdo, "device-params/min_temp", &_tempMin)); else Serial.println("FAILED: " + fbdo.errorReason());
    if(Firebase.RTDB.getDouble(&fbdo, "device-params/m-cal-value", &m_cal)); else Serial.println("FAILED: " + fbdo.errorReason());
    if(Firebase.RTDB.getDouble(&fbdo, "device-params/b-cal-value", &b_cal)); else Serial.println("FAILED: " + fbdo.errorReason());

    if(!hold){
      _tempOut = mlx.readObjectTempC();
      _ldrOut = analogRead(LDR_OUT_PIN);
      _ldrOut = (m_cal * _ldrOut) + b_cal;
      
      if (_ldrOut < 0) _ldrOut = 0;
    }

    lv_label_set_text_fmt(lux_label, "%4d LUX", _ldrOut);
    lv_label_set_text_fmt(temp_label, "%3d °C", _tempOut);
    lv_label_set_text_fmt(batt_label, "%d%%", _battPercent);

    if(_ldrOut > _luxMax || _ldrOut < _luxMin || _tempOut > _tempMax || _tempOut < _tempMin)digitalWrite(BUZZER_PIN, HIGH);
    else digitalWrite(BUZZER_PIN, LOW);
    
    FirebaseJson content;
    timestamp = getTime();
    content.set("/timestamp", timestamp);
    content.set("/temp-reading", _tempOut);
    content.set("/lux-reading", _ldrOut);
    content.set("/bat-reading", _battPercent);
    content.set("/save-flag", saveFlag);
    if(Firebase.RTDB.setJSON(&fbdo, "/device-live", &content)); else Serial.println("FAILED: " + fbdo.errorReason());
    if(Firebase.RTDB.pushJSON(&fbdo, "/device-records", &content)); else Serial.println("FAILED: " + fbdo.errorReason());

    saveFlag = false;
    prevMillis = millis();
  }
}

/*** Display callback to flush the buffer to screen ***/
void display_flush(lv_disp_drv_t *disp, const lv_area_t *area, lv_color_t *color_p){
  uint32_t w = (area->x2 - area->x1 + 1);
  uint32_t h = (area->y2 - area->y1 + 1);

  display.startWrite();
  display.setAddrWindow(area->x1, area->y1, w, h);
  display.pushColors((uint16_t *)&color_p->full, w * h, true);
  display.endWrite();

  lv_disp_flush_ready(disp);
}

/*** Touchpad callback to read the touchpad ***/
void touchpad_read(lv_indev_drv_t *indev_driver, lv_indev_data_t *data){
  uint16_t touchX, touchY;
  bool touched = display.getTouch(&touchX, &touchY);

  if (!touched) data->state = LV_INDEV_STATE_REL;
  else{
    data->state = LV_INDEV_STATE_PR;
    data->point.x = touchX;
    data->point.y = touchY;
  }
}

static void toggle_event_handler(lv_event_t *e){
  lv_event_code_t code = lv_event_get_code(e);
  if (code == LV_EVENT_VALUE_CHANGED){
    if(!hold) hold = true;
    else hold = false;
  
  }

  else if(code == LV_EVENT_CLICKED) {
    saveFlag = true;
  }
}

void lv_button_demo(void){
  lv_obj_t *label;

  // Save button
  lv_obj_t *btn1 = lv_btn_create(lv_scr_act());
  lv_obj_add_event_cb(btn1, toggle_event_handler, LV_EVENT_ALL, NULL);
  //lv_obj_set_pos(btn2, 160, 250);   /*Set its position*/
  lv_obj_align(btn1, LV_ALIGN_RIGHT_MID, -40, 140);
  lv_obj_set_size(btn1, 100, 50);   /*Set its size*/

  label = lv_label_create(btn1);
  lv_label_set_text(label, "Save");
  lv_obj_center(label);
  lv_obj_add_style(label, &genStyle, 0);

  // Hold button
  lv_obj_t *btn2 = lv_btn_create(lv_scr_act());
  lv_obj_add_event_cb(btn2, toggle_event_handler, LV_EVENT_ALL, NULL);
  lv_obj_add_flag(btn2, LV_OBJ_FLAG_CHECKABLE);
  //lv_obj_set_pos(btn2, 160, 250);   /*Set its position*/
  lv_obj_align(btn2, LV_ALIGN_LEFT_MID, 40, 140);
  lv_obj_set_size(btn2, 100, 50);   /*Set its size*/

  label = lv_label_create(btn2);
  lv_label_set_text(label, "Hold");
  lv_obj_center(label);
  lv_obj_add_style(label, &genStyle, 0);
  
}