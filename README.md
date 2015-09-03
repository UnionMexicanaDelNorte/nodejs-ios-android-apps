# nodejs-ios-android-apps
Nodejs MSSQL Server example communication with ios & android app with encrypted data

Setup

1.- Install nodejs in your server with http, url, mssql and crypto plugins

2.- Edit "activosFijos.js" file, change "initSalt", "endSalt", crypto key and create your own algorithm for create "clave" string.

3.- Edit "activosFijos.js" file to point your own mssql server and write your own queries.

4.- Run "activosFijos.js" in cmd: "node activosFijos.js". You should add this command line as session start in windows parameters.

5.- Test your url: http://localhost:90/?accion=1&argumento1=E00001&ei=XYZ
 Must say: "No dijiste la palabra correcta" 
Replace "XYZ" with your own hash which display in cmd

6.- Open your server to the world with port forwarding, if you dont have static ip, can use noip service
Test LAN outside

7.- Edit ScannerViewController.m in iOSApp and MainActivity.java in androidApp with your changes in the point two, and change the url to your own url

8.- Debug iOSApp and androidApp, make sure which "ei" string is the same that the "ei" string in the server


9.- Test and enjoy!
