# Google Photos TakeOut file organiser

## Background
You can download a local copy of all the content you have in Google Photos using their Takeout facility, which takes all of your photos and splits them into multiple archives which you can then extract locally.  If you'r extracting all the archives to the same folder, you'll end up with a structure like this;

```
/Takeout
        /archive_browser.html
        /Google Photos
                        /shared_album_comments.json
                        /user-generated-memory-titles.json
                        /Gallery 1
                            /<media files>
                            /<json meta files>
                        /Gallery 2
                            /<media files>
                            /<json meta files>
                        /Photos from 2020
                            /<media files>
                            /<json meta files>
                        /Photos from 2021
                            /<media files>
                            /<json meta files>
```

## Purpose

There are two problems that I wanted to solve with this structure;
- I wanted the folder dates to represent the content within them
- I'd like the photos and videos to have create and modified dates that respresent when they were taken
- I'd like to group gallery folders into years by placing them in sub folders
                    
 ## How to use it

 Simply drop the `organise-google-takeout.ps1` script into the Google Photos folder inside your takeout folder, so it will be sat at the same level as the Gallery folders, then run it!

 The folder structure you will end up with is;

```
/Takeout
        /archive_browser.html
        /Google Photos
                        /2020
                            /Gallery 1
                                /<media files>
                                /<json meta files>
                            /Photos from 2020
                                /<media files>
                                /<json meta files>
                        /2021
                            /Gallery 2
                                /<media files>
                                /<json meta files>
                            /Photos from 2021
                                /<media files>
                                /<json meta files>
```

### How does it work

Firstly media is sorted;
- Loops through each folder that isn't named as a year
- Loops through each media item (non-json file) in each folder
- find the corresponding json file for that media item and extracts the media taken date
- applies this date to the media item's created and updatd date
- finally, it finds the oldest file in the folder, and uses its date to update the folders crated and modified dates

Then the folders are moved
- Based on the folders created date, it takes the year
- It will then create a year folder, if it doesn't already exist for this given year
- Finally the gallery folder is moved into the year folder
