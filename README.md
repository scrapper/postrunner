# PostRunner

PostRunner is an application to manage FIT files such as those produced by Garmin products like the Forerunner 620. It allows you to import the files from the device and inspect them.

## Installation

PostRunner is a Ruby application. You need to have a Ruby 2.0 or later runtime environment installed.

    $ gem install postrunner

## Usage

To get started you need to connect your device to your computer and mount it as a drive. Only devices that expose their data as FAT file system are supported. Older devices use proprietary drivers and are not supported by postrunner. Once the device is mounted find out the full path to the directory that contains your FIT files. You can then import all files on the device.

    $ postrunner import /var/run/media/user/GARMIN/GARMIN/ACTIVITY/
    
The above command assumes that your device is mounted as /var/run/media/user. Please replace this with the path to your device. Files that have been imported previously will not be imported again. 

Now you can list all the FIT files in your data base.

    $ postrunner list
    
The first column is the index you can use to reference FIT files. To get a summary of the most recent activity use the following command.

    $ postrunner summary :1
    
To get a summary of the oldest activity you can use

    $ postrunner summary :-1
    
You can also get a full dump of the content of a FIT file.

    $ postrunner dump 1234568.FIT
    
If the file is already in the data base you can also use the reference notation.

    $ postrunner dump :1
    
This will provide you with a lot more information contained in the FIT files that is not available through Garmin Connect or most other tools.

## Contributing

PostRunner is currently work in progress. It does some things I want with files from my Garmin FR620. It's certainly possible to do more things and support more devices. Patches are welcome!

1. Fork it ( https://github.com/scrapper/postrunner/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
