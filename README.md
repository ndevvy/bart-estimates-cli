## BART Arrival estimates
A simple command line tool for retrieving and displaying information about
arrival times at BART stations.  

### Installation
Clone the repo.

`cd src && bundle install`

`ruby bart.rb {station}` to see estimates. Optionally, specify a direction; by
default all directions will be displayed.

`ruby ./bart.rb mont north`

`ruby ./bart.rb daly n`

`ruby ./bart.rb woak s`

### Flags
```bash
--no-color: Keep it simple.
--polling:  Automatically retrieves new data every 30 seconds. 
--polling-notify: Automatically retrieves new data and (in OS X) displays
notifications if there are new system advisory warnings. 
```

### Todo
- [] bash completion for station names
- [] notify when a train is x minutes away
