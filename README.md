this is a simple parser that reads socalgas greenbutton usage xml data. login to your account, go to analyze usage, and you should see a green button at the top right of your page. click on it and you'll see a box that lets you choose a a date range, its limited to like 400 days, but contains hourly usage.

once you have downloaded the file, edit the parse script, and set your influxdb account creds

execute the script by running greenParse.pl filename.xml

