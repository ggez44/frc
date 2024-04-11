## scout.rb
not maintained, has 2023 stuff (probably won't work for 2024)
but this looked at all events and did global rankings and stuff.

## schedule.rb
can ignore.. was an attempt at coming up with better schedules for quals, but didn't get very far

## rankings_old.rb
old version where you can just cut&paste results from thebluealliance event page, and it'll find the Estimated Point Share.

To explain the algorithm a bit:
    match 1: 90 points - team1, team2, team3 
    match 2: 70 points - team4, team5, team6 
    match 3: 80 points - team1, team5, team6
    match 4: ... 

we run iterations.. 
first iteration: 
    team1,2,3 all get equal shares of the 90 points from match 1 (30 each)
    team4,5,6 all get equal shares of the 60 points from match 2 (20 each)
    etc

assume at the end of the iteration: team1 is at 35points, team2 is at 30points, team3 is at 20points

2nd iteration: 
    team1 gets 35/(35+30+20) points of 90 points for match 1
    team2 gets 30/(35+30+20) points
    team3 gets 20(35+30+20) points

we iterated 50 times and the percent shares will stabilize


## rankings.rb
updated version that uses TBA's api instead.
this allows the algorithm to subtract out penalty points from the total score to be more accurate of offensive contribution

this version has 3 options.. ("ruby rankings.rb 2024cabe")
1 points share except this is able to subtract out penalty points to be more accurate 
-- this is mostly aligned with opr, but much better at dealing with fewer matches played
-- this is mostly aligned with epa in terms of results
2 foul points contributed.. same algorithm but looking at how many points the opposing alliance received.  So if a team got a "6.4"
it means that on average, they gave up 6.4 points worth of penalities to the other alliance.
-- note: thebluealliance insights tab has foul points, but it's based on what your own alliance received for points which is meaningless
3 climb percentage.. TBA api gives us who climbed, so this is not an approximation, but rather an exact percentage of how often a team successfully climbed.
this ignores "park"
