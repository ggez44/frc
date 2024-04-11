### scout.rb
not maintained, has 2023 stuff (probably won't work for 2024)
but this looked at all events and did global rankings and stuff.

### schedule.rb
can ignore.. was an attempt at coming up with better schedules for quals, but didn't get very far

### rankings_old.rb
old version where you can just cut&paste results from thebluealliance event page, and it'll find the Estimated Point Share.

To explain the algorithm a bit:
match 1: 90 points - team1, team2, team3 
match 2: 70 points - team4, team5, team6 
match 3: 80 points - team1, team5, team6
match 4: ... 

we run iterations.. 
first iteration: team1,2,3 all get equal shares of the 90 points from match 1 (30 each)
                 team4,5,6 all get equal shares of the 60 points from match 2 (20 each)
                 etc

                 assume at the end of the iteration: team1 is at 35points, team2 is at 30points, team3 is at 20points

2nd iteration: team1 gets 35/(35+30+20) points of 90 points for match 1
               team2 gets 30/(35+30+20) points
               team3 gets 20(35+30+20) points

we iterated 50 times and the percent shares will stabilize


### rankings.rb
updated version that uses TBA's api instead.
this allows the algorithm to subtract out penalty points from the total score to be more accurate of offensive contribution

this version also allows for 2 more stats:
- foul points contributed.. same algorithm but looking at how many points the opposing alliance received.  So if a team got a "6.4"
it means that on average, they gave up 6.4 points worth of penalities to the other alliance.
- climb percentage.. TBA alliance gives us who climbed, so this is not an approximation, but rather an exact percentage of how often a team successfully climbed.
this ignores "park"
