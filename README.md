## scout.rb
not maintained, has 2023 stuff (probably won't work for 2024)
but this looked at all events and did global rankings and stuff.

## schedule.rb
can ignore.. was an attempt at coming up with better schedules for quals, but didn't get very far

## rankings_old.rb
old version where you can just cut&paste results from thebluealliance event page, and it'll find the Estimated Point Share.

### Algorithm Explanation:

We run multiple iterations to distribute points among teams based on their performance in matches. Here's a breakdown of how the algorithm processes the data:

#### Match Data:
- **Match 1:** 90 points - Team1, Team2, Team3
- **Match 2:** 70 points - Team4, Team5, Team6
- **Match 3:** 80 points - Team1, Team5, Team6
- **Match 4:** ...

#### Iterations:

##### First Iteration:
- **Team1, Team2, Team3** all receive equal shares of the 90 points from Match 1, which is 30 each.
- **Team4, Team5, Team6** all receive equal shares of the 70 points from Match 2, which is about 23.33 each.

Assuming at the end of this iteration, the points are as follows:
- **Team1:** 35 points
- **Team2:** 30 points
- **Team3:** 20 points

##### Second Iteration:
- **Team1** receives \(35/(35+30+20)\) of the 90 points from Match 1.
- **Team2** receives \(30/(35+30+20)\) of the 90 points.
- **Team3** receives \(20/(35+30+20)\) of the 90 points.

#### Stabilization:
We iterate this process 50 times. After multiple iterations, the percentage shares of points among the teams will stabilize.


## rankings.rb
updated version that uses TBA's api instead, and uses the same algorithm as the \_old version
i left my TBA api key is in the file, better if you go get your own (it's free), 

This version has 3 options.. ("ruby rankings.rb 2024cabe")

1. **Points Share** - This is able to subtract out penalty points to be more accurate.
   - This is mostly aligned with OPR, but much better at dealing with fewer matches played.
   - This is mostly aligned with EPA in terms of results.
2. **Foul Points Contributed** - Same algorithm but looking at how many points the opposing alliance received. So if a team got a "6.4", it means that on average, they gave up 6.4 points worth of penalties to the other alliance.
   - Note: The Blue Alliance insights tab has foul points, but it's based on what your own alliance received for points which is meaningless.
3. **Climb Percentage** - The TBA API gives us who climbed, so this is not an approximation, but rather an exact percentage of how often a team successfully climbed. This ignores "park".

