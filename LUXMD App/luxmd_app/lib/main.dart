import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:luxmd_app/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LUX Meter Monitoring',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'LUX Meter Monitoring'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class DataPoint {
  final int time;
  final int value;

  DataPoint(this.time, this.value);
}

class _MyHomePageState extends State<MyHomePage> {
  int currentIndex = 0;

  String luxReading = '';
  String tempReading = '';
  String _batReading = '';
  String _luxReading = '';
  String _tempReading = '';
  String _calibrationB = '';
  String _calibrationM = '';
  String _maxLux = '';
  String _maxTemp = '';
  String _minLux = '';
  String _minTemp = '';

  int x = 0;
  int tempReadingNum = 0;
  int x_bat = 0;
  int maxLux = 0;
  int minLux = 0;
  int maxTemp = 0;
  int minTemp = 0;

  double calibration_m = 0;
  double calibration_b = 0;

  int luxReadingNum = 0;
  double battReadingNum = 0;

  String labelText = '';
  String queryName = '';
  String luxReadingRemark = '';
  String tempReadingRemark = '';

  final formKey = GlobalKey<FormState>();
  final TextEditingController _label = new TextEditingController();
  FirebaseDatabase database = FirebaseDatabase.instance;
  List<DataPoint> dataPoints = []; //LUX
  List<DataPoint> dataPoints2 = []; //Temp

  bool isLoading = false;
  bool _luxCritical = false;
  bool _tempCritical = false;
  bool _saveFlag = false;
  final int maxDataPoints = 20;

  @override
  void initState() {
    super.initState();
    DatabaseReference sensorData = database.ref('');
    DatabaseReference records = database.ref('device-records/');

    records.onChildAdded.listen((DatabaseEvent event) {
      final data = event.snapshot.value;

      if (data != null && data is Map<Object?, Object?>) {
        final Map<String, dynamic> typedData = data.cast<String, dynamic>();
        final timestamp = data['timestamp'] as int;
        final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final dataValue = data['lux-reading'] as int;
        final dataValue2 = data['temp-reading'] as int;

        setState(() {
          // Add the new data point to the list
          dataPoints.add(DataPoint(timestamp, dataValue));
          dataPoints2.add(DataPoint(timestamp, dataValue2));
          if (dataPoints.length > maxDataPoints) {
            dataPoints.removeAt(0); // Remove the oldest data point.
            dataPoints2.removeAt(0);
          }
        });
      }
    });

    sensorData.onValue.listen((DatabaseEvent event) {
      _batReading =
          event.snapshot.child('device-live/bat-reading').value.toString();
      _luxReading =
          event.snapshot.child('device-live/lux-reading').value.toString();
      _tempReading =
          event.snapshot.child('device-live/temp-reading').value.toString();
      _calibrationB =
          event.snapshot.child('device-params/b-cal-value').value.toString();
      _calibrationM =
          event.snapshot.child('device-params/m-cal-value').value.toString();
      _maxLux = event.snapshot.child('device-params/max_lux').value.toString();
      _minLux = event.snapshot.child('device-params/min_lux').value.toString();
      _maxTemp =
          event.snapshot.child('device-params/max_temp').value.toString();
      _minTemp =
          event.snapshot.child('device-params/min_temp').value.toString();

      _saveFlag = event.snapshot.child('device-live/save-flag').value as bool;
      //
      //x = int.parse(_luxReading);
      tempReadingNum = int.parse(_tempReading);
      x_bat = int.parse(_batReading);
      calibration_m = double.parse(_calibrationM);
      calibration_b = double.parse(_calibrationB);
      maxLux = int.parse(_maxLux);
      minLux = int.parse(_minLux);
      maxTemp = int.parse(_maxTemp);
      minTemp = int.parse(_minTemp);

      luxReadingNum = int.parse(_luxReading);
      //luxReadingNum.round();

      if (_saveFlag == true) {
        sensorData.child('device-live').update({"save-flag": false});
        saveData();
      }

      //
      setState(() {
        _saveFlag = false;
        if (luxReadingNum > maxLux || luxReadingNum < minLux) {
          luxReadingRemark = "CRITICAL";
          _luxCritical = true;
        } else {
          luxReadingRemark = "STABLE";
          _luxCritical = false;
        }

        if (tempReadingNum > maxTemp || tempReadingNum < minTemp) {
          tempReadingRemark = "CRITICAL";
          _tempCritical = true;
        } else {
          tempReadingRemark = "STABLE";
          _tempCritical = false;
        }

        luxReading = luxReadingNum.toInt().toString();
        tempReading = tempReadingNum.toInt().toString();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [],
        elevation: 0,
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        title: const Text(
          "IoT LUX Meter",
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: currentIndex == 0
          ? Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 80),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        luxDisplay(),
                        SizedBox(height: 10),
                        tempDisplay(),
                        SizedBox(height: 30),
                        SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                )),
                            child: const Text("Save",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16)),
                            onPressed: () {
                              saveData();
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('records')
                  .orderBy("timeDate", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                else {
                  return Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Expanded(
                            child: ListView.builder(
                                itemCount: snapshot.data!.docs.length,
                                itemBuilder: (context, index) {
                                  var data = snapshot.data!.docs[index].data()
                                      as Map<String, dynamic>;
                                  DocumentReference snapRef =
                                      snapshot.data!.docs[index].reference;

                                  return GestureDetector(
                                    onTap: () {
                                      //view record
                                      popupDialog(data, snapRef);
                                    },
                                    child: cardLayout(data),
                                  );
                                }))
                      ],
                    ),
                  );
                }
              }),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey.withOpacity(0.5),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            label: '',
            icon: Icon(Icons.add),
          ),
          BottomNavigationBarItem(
            label: '',
            icon: Icon(Icons.manage_search_rounded),
          )
        ],
        currentIndex: currentIndex,
        onTap: (int index) {
          setState(() {
            currentIndex = index;
          });
        },
      ),
    );
  }

  void _updateLabel(DocumentReference doc, String newValue) {
    FirebaseFirestore.instance
        .collection('records')
        .doc(doc.id)
        .update({'label': newValue});
  }

  popupDialog(var j, DocumentReference doc) {
    String newlabel = j['label'];
    int saveLux = j['luxReading'];
    int saveTemp = j['tempReading'];

    return showDialog(
      barrierDismissible: true,
      context: context,
      builder: (context) {
        return AlertDialog(
            actions: [
              TextButton(
                child: Text("SAVE"),
                onPressed: () {
                  _updateLabel(doc, newlabel);
                  Navigator.of(context).pop();
                },
              )
            ],
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10))),
            title: Text('Record Details'),
            content: SingleChildScrollView(
              child: Container(
                width: 500,
                height: 500,
                child: Column(children: [
                  Row(
                    children: [
                      Text(
                        "Label: ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        width: 200,
                        child: TextFormField(
                            initialValue: newlabel,
                            onFieldSubmitted: (newValue) {
                              newlabel = newValue;
                            }),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Container(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: dataPoints.asMap().entries.map((entry) {
                                return FlSpot(entry.value.time.toDouble(),
                                    entry.value.value.toDouble());
                              }).toList(),
                              isCurved: false,
                              barWidth: 2,
                              color: Colors.blue,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(show: false),
                            ),
                            LineChartBarData(
                              spots: [
                                FlSpot(dataPoints.elementAt(9).time.toDouble(),
                                    saveLux.toDouble())
                              ],
                              isCurved: false,
                              barWidth: 2,
                              color: Colors.red,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(show: false),
                            ),
                          ],
                          titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                  axisNameWidget: Text(
                                    "LUX",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10),
                                  ),
                                  sideTitles: SideTitles(
                                    getTitlesWidget: (value, meta) => Text(
                                      value.toInt().toString(),
                                      style: TextStyle(fontSize: 9),
                                    ),
                                    interval: 100,
                                    showTitles: true,
                                  )),
                              bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                getTitlesWidget: (value, meta) {
                                  DateTime date =
                                      DateTime.fromMillisecondsSinceEpoch(
                                          value.toInt());
                                  String formattedTime =
                                      DateFormat("h:mm").format(date);
                                  return Text(
                                    formattedTime,
                                    style: TextStyle(fontSize: 9),
                                  );
                                },
                                showTitles: false,
                              )))),
                    ),
                  ),
                  SizedBox(height: 20),
                  Container(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: dataPoints2.asMap().entries.map((entry) {
                                return FlSpot(entry.value.time.toDouble(),
                                    entry.value.value.toDouble());
                              }).toList(),
                              isCurved: false,
                              barWidth: 2,
                              color: Colors.blue,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(show: false),
                            ),
                            LineChartBarData(
                              spots: [
                                FlSpot(dataPoints2.elementAt(7).time.toDouble(),
                                    saveTemp.toDouble())
                              ],
                              isCurved: false,
                              barWidth: 2,
                              color: Colors.red,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(show: false),
                            ),
                          ],
                          titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                  axisNameWidget: Text(
                                    "TEMPERATURE",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10),
                                  ),
                                  sideTitles: SideTitles(
                                    getTitlesWidget: (value, meta) => Text(
                                      value.toInt().toString(),
                                      style: TextStyle(fontSize: 9),
                                    ),
                                    interval: 10,
                                    showTitles: true,
                                  )),
                              bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                getTitlesWidget: (value, meta) {
                                  DateTime date =
                                      DateTime.fromMillisecondsSinceEpoch(
                                          value.toInt());
                                  String formattedTime =
                                      DateFormat("h:mm").format(date);
                                  return Text(
                                    formattedTime,
                                    style: TextStyle(fontSize: 9),
                                  );
                                },
                                showTitles: false,
                              )))),
                    ),
                  )
                ]),
              ),
            ));
      },
    );
  }

  Container luxDisplay() {
    return Container(
      alignment: Alignment.center,
      width: 300,
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey, width: 1),
          borderRadius: BorderRadius.circular(20)),
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('LUX',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                )),
            SizedBox(width: 10),
            SizedBox(
                child: _luxCritical
                    ? Container(
                        padding: EdgeInsets.all(5),
                        color: Colors.red[400],
                        child: Text('Critical',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                                fontSize: 12)))
                    : Container(
                        padding: EdgeInsets.all(5),
                        color: Colors.green[400],
                        child: Text('Stable',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                                fontSize: 12))))
          ]),
          Text('${luxReading} lux',
              style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 50))
        ],
      ),
    );
  }

  Container tempDisplay() {
    return Container(
      alignment: Alignment.center,
      width: 300,
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey, width: 1),
          borderRadius: BorderRadius.circular(20)),
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Temperature',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                )),
            SizedBox(width: 10),
            SizedBox(
                child: _tempCritical
                    ? Container(
                        padding: EdgeInsets.all(5),
                        color: Colors.red[400],
                        child: Text('Critical',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                                fontSize: 12)))
                    : Container(
                        padding: EdgeInsets.all(5),
                        color: Colors.green[400],
                        child: Text('Stable',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                                fontSize: 12))))
          ]),
          Text('${tempReading}°C',
              style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 50))
        ],
      ),
    );
  }

  Card cardLayout(var i) {
    Timestamp t = i['timeDate'];
    DateTime date = t.toDate();
    String dateTime = DateFormat("MMMM d, yyyy h:mm aa").format(date);

    return Card(
      elevation: 5,
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      child: Container(
        padding: EdgeInsets.all(15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
                child: Center(
              child: Column(
                children: [
                  Text(
                    '${i['luxReading']} lux',
                    style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  ),
                  Text(
                    '${i['tempReading']}°C',
                    style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  )
                ],
              ),
            )),
            Expanded(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 10, right: 10),
                        child: Text(
                          '${i['label']}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                          padding: EdgeInsets.only(left: 10, right: 10, top: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Icon(Icons.calendar_month_rounded,
                                  color: Colors.grey, size: 16),
                              Container(
                                margin: EdgeInsets.only(left: 10),
                                child: Text(
                                  dateTime,
                                  style: TextStyle(fontSize: 13),
                                ),
                              )
                            ],
                          )),
                      Padding(
                          padding: EdgeInsets.only(left: 10, right: 10, top: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Icon(Icons.light_mode_rounded,
                                  color: Colors.grey, size: 16),
                              Container(
                                  margin: EdgeInsets.only(left: 10),
                                  child: i['luxReadingRemark'] == 'STABLE'
                                      ? Container(
                                          padding: EdgeInsets.all(5),
                                          color: Colors.green[400],
                                          child: Text('Stable',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.normal,
                                                  fontSize: 12)))
                                      : Container(
                                          padding: EdgeInsets.all(5),
                                          color: Colors.red[400],
                                          child: Text('Critical',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.normal,
                                                  fontSize: 12))))
                            ],
                          )),
                      Padding(
                          padding: EdgeInsets.only(left: 10, right: 10, top: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Icon(Icons.thermostat_rounded,
                                  color: Colors.grey, size: 16),
                              Container(
                                  margin: EdgeInsets.only(left: 10),
                                  child: i['tempReadingRemark'] == 'STABLE'
                                      ? Container(
                                          padding: EdgeInsets.all(5),
                                          color: Colors.green[400],
                                          child: Text('Stable',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.normal,
                                                  fontSize: 12)))
                                      : Container(
                                          padding: EdgeInsets.all(5),
                                          color: Colors.red[400],
                                          child: Text('Critical',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.normal,
                                                  fontSize: 12))))
                            ],
                          )),
                    ],
                  ),
                ))
          ],
        ),
      ),
    );
  }

  saveData() async {
    if (formKey.currentState!.validate()) {
      setState(() {
        isLoading = true;
      });

      final records = FirebaseFirestore.instance.collection('records').doc();
      final data = {
        'label': labelText,
        'timeDate': Timestamp.now(),
        'luxReading': int.parse(luxReading),
        'luxReadingRemark': luxReadingRemark,
        'tempReading': int.parse(tempReading),
        'tempReadingRemark': tempReadingRemark,
      };

      await records.set(data);

      setState(() {
        isLoading = false;
      });

      _label.clear();

      showSnackBar(context, 'Successfully Saved');
    }
  }
}

void showSnackBar(context, message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(
      message,
      style: const TextStyle(fontSize: 14),
    ),
    duration: const Duration(seconds: 2),
    action: SnackBarAction(
      label: "OK",
      onPressed: () {},
      textColor: Colors.white,
    ),
  ));
}
