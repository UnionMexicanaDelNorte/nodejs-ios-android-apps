package umn.activos.fijos;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.Handler;
import android.os.Message;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.util.Base64;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.Toast;

import com.google.zxing.integration.android.IntentIntegrator;
import com.google.zxing.integration.android.IntentResult;

import org.apache.commons.codec.binary.Hex;
import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

public class MainActivity extends AppCompatActivity {
    public MainActivity reference;
    public String ei, argumento1,urlString;
    public boolean firstTime = true;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        reference = this;
        if(firstTime)
        {
            firstTime=false;
            IntentIntegrator integrator = new IntentIntegrator(this);
            integrator.initiateScan();
        }

    }


    private boolean isNetworkAvailable() {
        ConnectivityManager connectivityManager
                = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo activeNetworkInfo = connectivityManager.getActiveNetworkInfo();
        //return activeNetworkInfo != null && activeNetworkInfo.isConnected();
        return activeNetworkInfo != null && activeNetworkInfo.isConnectedOrConnecting();
    }

    private void hazPost()
    {
        Toast.makeText(getBaseContext(),
                "Please wait, connecting to server.",
                Toast.LENGTH_SHORT).show();


        // Create Inner Thread Class
        Thread background = new Thread(new Runnable() {


            // After call for background.start this run method call
            public void run() {
                try {
                    URL url = new URL(urlString);
                    HttpURLConnection urlConnection = (HttpURLConnection) url.openConnection();

                    try {
                        InputStream in = new BufferedInputStream(urlConnection.getInputStream());
                        // Acciones a realizar con el flujo de datos
                        BufferedReader streamReader = new BufferedReader(new InputStreamReader(in, "UTF-8"));
                        StringBuilder responseStrBuilder = new StringBuilder();

                        String inputStr;
                        while ((inputStr = streamReader.readLine()) != null)
                            responseStrBuilder.append(inputStr);
                        JSONArray x = new JSONArray(responseStrBuilder.toString());
                        JSONObject test = x.getJSONObject(0);
                        String ASSET_CODE = test.getString("ASSET_CODE");
                        String DESCR = test.getString("DESCR");
                        String START_PERD = test.getString("START_PERD");
                        String LAST_PERD = test.getString("LAST_PERD");
                        String BASE_GROSS = test.getString("BASE_GROSS");
                        String BASE_DEP = test.getString("BASE_DEP");
                        String BASE_NET = test.getString("BASE_NET");
                        String BASE_PCENT = test.getString("BASE_PCENT");
                        final String message = "El Activo Fijo tiene las siguientes propiedades:\n\nID: "+ASSET_CODE+"\nDescripción: "+DESCR+"\nPeriodo Inicio: "+START_PERD+"\nÚltimo periodo despreciado: "+LAST_PERD+"\nBase: $"+BASE_GROSS+"\nDepreciado: $"+BASE_DEP+"\nNeto: $"+BASE_NET+"\nPorcentaje de Dep: %"+BASE_PCENT;

                        reference.runOnUiThread(new Runnable() {
                            public void run() {
                                new AlertDialog.Builder(reference)
                                        .setTitle("Activo Fijo")
                                        .setMessage(message)
                                        .setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() {
                                            public void onClick(DialogInterface dialog, int which) {
                                                IntentIntegrator integrator = new IntentIntegrator(reference);
                                                integrator.initiateScan();
                                            }
                                        })
                                        .setIcon(android.R.drawable.ic_dialog_alert)
                                        .show();
                            }
                        });



                    }
                    catch (Exception e)
                    {
                        Log.i("Animation", e.toString());

                    }
                    finally {
                        urlConnection.disconnect();
                    }


                } catch (Throwable t) {
                    // just end the background thread
                    Log.i("Animation", "Thread  exception " + t);
                }
            }

            private void threadMsg(String msg) {

                if (!msg.equals(null) && !msg.equals("")) {
                    Message msgObj = handler.obtainMessage();
                    Bundle b = new Bundle();
                    b.putString("message", msg);
                    msgObj.setData(b);
                    handler.sendMessage(msgObj);
                }
            }

            // Define the Handler that receives messages from the thread and update the progress
            private final Handler handler = new Handler() {

                public void handleMessage(Message msg) {

                    String aResponse = msg.getData().getString("message");

                    if ((null != aResponse)) {

                        // ALERT MESSAGE
                        Toast.makeText(
                                getBaseContext(),
                                "Server Response: "+aResponse,
                                Toast.LENGTH_SHORT).show();
                    }
                    else
                    {

                        // ALERT MESSAGE
                        Toast.makeText(
                                getBaseContext(),
                                "Not Got Response From Server.",
                                Toast.LENGTH_SHORT).show();
                    }

                }
            };

        });
        // Start Thread
        background.start();
    }
    public void onActivityResult(int requestCode, int resultCode, Intent intent) {
        IntentResult scanResult = IntentIntegrator.parseActivityResult(requestCode, resultCode, intent);
        if (scanResult != null) {

            DateFormat df = new SimpleDateFormat("yyyyMMdd");
            String now = df.format(new Date());

            argumento1 = scanResult.getContents();

            if(argumento1!=null && !argumento1.isEmpty())
            {

                String initSalt = "%&/mysalt5=";
                String endSalt = "ThisIsMyEasyToRememberSalt";

                String message = initSalt+now+endSalt;
                String secret = "7HolaAmigosComoEstan7";


                try {
                    Mac sha_HMAC = Mac.getInstance("HmacSHA512");

                    SecretKeySpec secret_key = new SecretKeySpec(secret.getBytes(), "HmacSHA512");
                    sha_HMAC.init(secret_key);

                    //String output = new String(Base64.encodeToString(Hex.decodeHex(message.toCharArray())));


                    ei = new String(Hex.encodeHex(sha_HMAC.doFinal(message.getBytes())));
                    urlString = new String("http://sunplus.redirectme.net:90/?accion=1&argumento1="+argumento1+"&ei="+ei);

                    if(isNetworkAvailable())
                    {
                        try {
                            finishActivity(requestCode);
                            hazPost();
                        }
                        catch (Exception e)
                        {

                        }

                    } else {
                        new AlertDialog.Builder(reference)
                                .setTitle("Internet error")
                                .setMessage("No esta disponible una conexión a internet, por favor, conectese a internet para continuar.")
                                .setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() {
                                    public void onClick(DialogInterface dialog, int which) {
                                        // continue with delete
                                    }
                                })
                                .setIcon(android.R.drawable.ic_dialog_alert)
                                .show();
                    }



                }
                catch (Exception e){
                    System.out.println("Error2: "+e.toString());
                }

            }
        }
        // else continue with any other code you need in the method
    }
    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_main, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();

        //noinspection SimplifiableIfStatement
        if (id == R.id.action_settings) {
            return true;
        }

        return super.onOptionsItemSelected(item);
    }
}
