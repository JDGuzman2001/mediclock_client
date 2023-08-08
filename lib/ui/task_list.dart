import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';


class TaskListScreen extends StatefulWidget {
  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  // Lista de estados de checkbox para cada tarea
  List<List<bool?>> taskStatusList = [];
  List<String> selectedDays = [];

  List<bool?> taskStatus = [];
  List<TimeOfDay> principalTasks = [];
  Map<TimeOfDay, List<String>> tasksMap = {};

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _requestNotificationPermissions();
    _loadData(); // Load data when the app starts
  }
  void _loadData() async {
    print("Loading data...");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Load the lists from shared preferences, or initialize them with default values
    List<String>? savedPrincipalTasks = prefs.getStringList('principalTasks');
    List<String>? savedSelectedDays = prefs.getStringList('selectedDays');

    List<List<bool?>> loadedTaskStatusList = [];

    // Load taskStatusList from shared preferences
    for (String timeString in savedPrincipalTasks ?? []) {
      List<String>? savedTaskStatus = prefs.getStringList('taskStatus_$timeString');
      List<bool?> taskStatus = savedTaskStatus?.map((status) => status == 'true').toList() ?? [];
      loadedTaskStatusList.add(taskStatus);
    }

    setState(() {
      principalTasks = savedPrincipalTasks?.map((time) => _parseTime(time)).toList() ?? [];
      selectedDays = savedSelectedDays ?? [];
      taskStatusList = loadedTaskStatusList;
    });

    for (int index = 0; index < principalTasks.length; index++) {
    TimeOfDay taskTime = principalTasks[index];
    _scheduleNotification(index, taskTime);
  }
  }
  void _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Save the lists to shared preferences
    prefs.setStringList('principalTasks', principalTasks.map((time) => _formatTime24h(time)).toList());
    prefs.setStringList('selectedDays', selectedDays);

    // Save taskStatusList to shared preferences
    for (int i = 0; i < principalTasks.length; i++) {
      List<bool?> taskStatus = taskStatusList[i];
      List<String> taskStatusStrings = taskStatus.map((status) => status?.toString() ?? 'false').toList();
      String timeString = _formatTime24h(principalTasks[i]);
      prefs.setStringList('taskStatus_$timeString', taskStatusStrings);
    }
  }
   @override
  void dispose() {
    _saveData(); // Save the data when the app is closed
    super.dispose();
  }

  void _requestNotificationPermissions() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(AndroidNotificationChannel(
          'alarm_channel',
          'Alarm Channel',
          'Channel for alarms',
          importance: Importance.high,
          playSound: true,
        ));
  }
  


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        title:Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/Mediclock_white.png', width: 40.0, height: 40.0,),
            SizedBox(width: 10.0,),
            Text('Horarios de tus medicamentos', style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),),
            SizedBox(width: 10.0,),

          ],
        ),
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: ListView.builder(
          itemCount: principalTasks.length,
          itemBuilder: (context, index) {
            List<bool?> taskStatus = taskStatusList[index] ?? [];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
              child: Container(
                decoration: BoxDecoration(
                    border: Border.all(
                    color: Colors.grey,
                  ),
                ),    
                  child: ExpansionTile(                
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                          Text(
                            _formatTimeAMPM(principalTasks[index]), // Mostrar la hora en formato AM/PM
                            style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              _deletePrincipalTask(index);
                            },
                          ),
                      ],
                    ),
                    children: _buildTasksList(principalTasks[index], taskStatus, index),
                  ),
              
              ),
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat, // Ajustar la posición de los botones
      floatingActionButton: Padding(
        padding: EdgeInsets.only(left: 10, right: 10),
        child: Row( // Usar un Row para colocar ambos botones
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              backgroundColor: Colors.black, // Color del primer botón (izquierda)
              onPressed: () async  {
                //_launchClockApp;
                await LaunchApp.openApp(
                  androidPackageName: 'com.google.android.deskclock', 
                  iosUrlScheme: 'clockapp://' 
                );
              },
              child: Icon(Icons.access_alarm),
            ),
            SizedBox(width: 16), // Espacio entre los botones
            FloatingActionButton(
              backgroundColor: Colors.blue, // Color del segundo botón (derecha)
              onPressed: () async {
                TimeOfDay? selectedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );

                if (selectedTime != null) {
                  setState(() {
                    principalTasks.add(selectedTime);
                    tasksMap[selectedTime] = [];
                    taskStatusList.add([]);
                    //_scheduleNotification( selectedTime); // Schedule the notification for the selected time
                    _scheduleNotification(principalTasks.length - 1, selectedTime);
                  });
                  showDialog(
                    context: context, 
                    builder: (context) => AlertDialog(
                      title: Text('Hora agregada'),
                      content: Text('Recuerda poner una alarma a la hora seleccionada con la aplicación de alarma de tu teléfono'),
                      actions: [
                        TextButton(
                          child: Text('OK'),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    )
                    );
                }
              },
              child: Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllSelectedAlertDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lista completada'),
        content: Text('Recuerda volver a hacer la lista para cuando la vuelvas a necesitar ya que la notificación solo se muestra una vez por lista'),
        actions: [
          TextButton(
            child: Text('OK'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
  
  void _checkAllSelected(int index) {
    List<bool?> taskStatus = taskStatusList[index]!;
    bool allSelected = !taskStatus.contains(false); // Verificar si todos los checkboxes están seleccionados
    if (allSelected) {
      _showAllSelectedAlertDialog(); // Mostrar el AlertDialog si todos están seleccionados
    }
  }

  List<Widget> _buildTasksList(TimeOfDay principalTask, List<bool?> taskStatus, int index) {
    List<Widget> taskWidgets = [];

    if (tasksMap.containsKey(principalTask)) {
      List<String> tasks = tasksMap[principalTask]!;
      for (int i = 0; i < tasks.length; i++) {
        taskWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border.all(
                  color: Colors.black,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Checkbox(
                    value: taskStatus[i],
                    onChanged: (value) {
                      setState(() {
                        taskStatus[i] = value; // Actualizar el estado específico
                        _checkAllSelected(index); // Verificar si todos están seleccionados al cambiar un checkbox
                      });
                    },
                  ),
                  Text(tasks[i], style: TextStyle(fontSize: 16.0),),
                  IconButton(
                    icon: Icon(Icons.delete),
                    color: Colors.grey,
                    onPressed: () {
                      setState(() {
                        tasks.removeAt(i);
                        taskStatus.removeAt(i);
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    taskWidgets.add(
      ElevatedButton(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(Colors.blue),
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              String newTask = '';
              return AlertDialog(
                title: Text('Agregar medicamento'),
                content: TextField(
                  onChanged: (value) {
                    newTask = value;
                  },
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text('Cancelar'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text('Agregar'),
                    onPressed: () {
                      setState(() {
                        if (tasksMap.containsKey(principalTask)) {
                          tasksMap[principalTask]!.add(newTask);
                        } else {
                          tasksMap[principalTask] = [newTask];
                        }
                        taskStatus.add(false);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        },
        child: Text('Agregar medicamento'),
      ),
    );

    return taskWidgets;
  }

  void _deletePrincipalTask(int index) {
    setState(() {
      TimeOfDay taskToDelete = principalTasks[index];
      principalTasks.removeAt(index);
      tasksMap.remove(taskToDelete);
      taskStatusList.removeAt(index);
    });
  }

  void _scheduleNotification(int notificationId, TimeOfDay selectedTime) async {
    DateTime now = DateTime.now();
    DateTime scheduledTime = DateTime(now.year, now.month, now.day, selectedTime.hour, selectedTime.minute);

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(Duration(days: 1));
    }
    String formattedampmTime = _formatTimeAMPM(selectedTime); // Obtener la hora en formato AM/PM
    String formattedTime = _formatTime24h(selectedTime); // Obtener la hora en formato 24h
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'alarm_channel',
      'Alarm Channel',
      'Channel for alarms',
      icon: 'ic_notification',
      importance: Importance.high,
      playSound: true,
    );

    var iOSPlatformChannelSpecifics = IOSNotificationDetails();

    var platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics, iOS: iOSPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.schedule(
      //0, // notification id
      notificationId,
      'Recordatorio de medicamento(s)', // notification title
      '$formattedampmTime', // notification body en formato 24h
      scheduledTime,
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
    );
  }

   String _formatTimeAMPM(TimeOfDay timeOfDay) {
    int hour = timeOfDay.hour;
    int minute = timeOfDay.minute;
    String period = (hour >= 12) ? 'PM' : 'AM';

    if (hour > 12) {
      hour -= 12;
    } else if (hour == 0) {
      hour = 12;
    }

    String hourFormatted = hour.toString().padLeft(2, '0');
    String minuteFormatted = minute.toString().padLeft(2, '0');

    return '$hourFormatted:$minuteFormatted $period';
  }

  String _formatTime24h(TimeOfDay timeOfDay) {
  String hour = timeOfDay.hour.toString().padLeft(2, '0');
  String minute = timeOfDay.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
TimeOfDay _parseTime(String timeString) {
  List<String> parts = timeString.split(':');
  int hour = int.parse(parts[0]);
  int minute = int.parse(parts[1]);
  return TimeOfDay(hour: hour, minute: minute);
}


}