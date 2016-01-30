# PostRunner

PostRunner is an application to manage FIT files such as those
produced by Garmin products like the Forerunner 620 (FR620) and Fenix
3. It allows you to import the files from the device and inspect them.
In addition to the common features like plotting pace, heart rates,
elevation and other captured values it also provides a heart rate
variability (HRV) analysis. It can also update satellite orbit prediction
(EPO) data on the device to speed-up fix times. It is an offline
alternative to Garmin Connect.

## Installation

PostRunner is a [http://www.ruby-lang.org](Ruby) application. You need
to have a Ruby 2.0 or later runtime environment installed.  This
application was developed and tested on Linux but may work on other
operating systems as well.

```
$ gem install postrunner
```

## Usage

### Importing FIT files

To get started you need to connect your device to your computer and
mount it as a disk drive. Only devices that expose their data as FAT file
system are supported. Older devices use proprietary drivers and are
not supported by postrunner. Once the device is mounted find out the
full path to the directory that contains your FIT files. You can then
import all files on the device.

```
$ postrunner import /run/media/$USER/GARMIN/GARMIN/ACTIVITY/
```
    
The above command assumes that your device is mounted as
/run/media/$USER. Please replace $USER with your login name and the
path with the path to your device. Files that have been imported
previously will not be imported again. 

### Viewing FIT file data on the console

Now you can list all the FIT files in your data base.

```
$ postrunner list
```
    
The first column is the index you can use to reference FIT files. To
get a summary of the most recent activity use the following command.
References to already imported activities start with a colon followed
by the index number.

```
$ postrunner summary :1
```

To get a summary of the oldest activity you can use

```
$ postrunner summary :-1
```

To select multiple activities you can use a range.

```
$ postrunner summary :1-3
```

You can also get a full dump of the content of a FIT file.

```
$ postrunner dump 1234568.FIT
```
    
If the file is already in the data base you can also use the reference
notation.

```
$ postrunner dump :1
```
    
This will provide you with a lot more information contained in the FIT
files that is not available through Garmin Connect or most other
tools.

When you upload your FIT data to the Garmin Connect site using WiFi or
Garmin Software, your device will be updated with 7 days worth of
Extended Prediction Orbit (EPO) data. The GPS receiver in your device
can use this data to acquire GPS locks much faster during the next 7
days. To fetch the current set of EPO data, just use the following
command while you have your device mounted via USB.

```
$ postrunner update-gps
```

This was tested on the FR620 and will probably also work on the FR220.
Other devices may work, but you use this at your own risk. This
feature will download a file called EPO.BIN and copy it to
GARMIN/REMOTESW/EPO.BIN.

### Viewing FIT file data in your web browser

You can also view the full details of your activity in your browser.
This view includes a map (internet connection for map data required)
and charts for speed, pace, heart rate, cadence and the like.

```
$ postrunner show
```

This will open an overview of the most recent activities in your web
browser. It will use Firefox by default. You can overwrite this by
setting the BROWSER environment variable.

To view a specific run directly, you can use similar specifications
like those explained above.

```
$ postrunner show :1
```

## Contributing

PostRunner is currently work in progress. It does some things I want
with files from my Garmin FR620. It's certainly possible to do more
things and support more devices. Patches are welcome!

1. Fork it ( https://github.com/scrapper/postrunner/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

PostRunner is licensed under the GNU GPL version 2.

The distribution includes third party components that are licensed
under different OSI compatible terms.

* flot: MIT License
* jquery: MIT License
* openlayers: 2 clause BSD license
* Oxygen Icons: GNU LGPLv3 (https://techbase.kde.org/Projects/Oxygen/Licensing)

