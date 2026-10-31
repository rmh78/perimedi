---- MODULE SymptomSync ----
\* a is the earlier sort and the lower id. A same-name fold keeps a.
\* A record id is either the unique date#id writers store, or the empty default.
\* Left out: prefer's tie-break, chains longer than one hop, CloudKit's transport.

EXTENDS Integers, TLC

CONSTANTS Ids, Days, Names, LogIds

VARIABLES present, nm, has, empty, memory, shown, phase, view, combined, owned, refreshed

vars == <<present, nm, has, empty, memory, shown, phase, view, combined, owned, refreshed>>

SameName == present["a"] /\ present["b"] /\ nm["a"] = nm["b"]

Stored(mem) == IF SameName THEN "ba" ELSE mem

Applies(mem, pres) ==
  \/ (mem = "ba" /\ pres["a"] /\ ~pres["b"])
  \/ (mem = "ab" /\ pres["b"] /\ ~pres["a"])

Target(id, mem, pres) ==
  IF id = "b" /\ mem = "ba" /\ Applies(mem, pres) THEN "a"
  ELSE IF id = "a" /\ mem = "ab" /\ Applies(mem, pres) THEN "b"
  ELSE id

Feeds(id, day, mem, pres) ==
  \/ (has[id][day] /\ Target(id, mem, pres) = id)
  \/ (id = "a" /\ has["b"][day] /\ Target("b", mem, pres) = "a")
  \/ (id = "b" /\ has["a"][day] /\ Target("a", mem, pres) = "b")

ShownAt(id, day, mem, pres) ==
  Feeds(id, day, mem, pres) /\ pres[id]

ShownFrom(mem, pres) == [i \in Ids |-> [d \in Days |-> ShownAt(i, d, mem, pres)]]

\* Failure snapshot passes memory none, then fold still discovers a fresh pair
\* from the rows it was given. It does not read the key it just saved.
GapMem == IF SameName THEN "ba" ELSE "none"

SharedEmpty ==
  \E i1, i2 \in Ids, d1, d2 \in Days :
    /\ has[i1][d1] /\ empty[i1][d1]
    /\ has[i2][d2] /\ empty[i2][d2]
    /\ (i1 # i2 \/ d1 # d2)

NextPresent ==
  IF SameName THEN [present EXCEPT !["b"] = FALSE] ELSE present

\* Unique date#id values differ across days, so they never clash across days.
ExtraUnique(i, day, mem) ==
  /\ has[i][day]
  /\ ~empty[i][day]
  /\ \E j \in Ids :
      /\ j # i
      /\ has[j][day]
      /\ ~empty[j][day]
      /\ Target(j, mem, NextPresent) = Target(i, mem, NextPresent)
      /\ j = "a" /\ i = "b"

Deleted(i, day, mem) == ExtraUnique(i, day, mem)

NextHas(mem) ==
  [i \in Ids |-> [d \in Days |->
    \/ (has[i][d] /\ ~Deleted(i, d, mem) /\ Target(i, mem, NextPresent) = i)
    \/ \E j \in Ids :
        j # i /\ has[j][d] /\ ~Deleted(j, d, mem) /\ Target(j, mem, NextPresent) = i]]

NextEmpty(mem) ==
  [i \in Ids |-> [d \in Days |->
    empty[i][d] /\ NextHas(mem)[i][d] /\ ~SharedEmpty]]

Init ==
  /\ present = [i \in Ids |-> FALSE]
  /\ nm = [i \in Ids |-> "fog"]
  /\ has = [i \in Ids |-> [d \in Days |-> FALSE]]
  /\ empty = [i \in Ids |-> [d \in Days |-> FALSE]]
  /\ memory = "none"
  /\ shown = [i \in Ids |-> [d \in Days |-> FALSE]]
  /\ phase = "idle"
  /\ view = "live"
  /\ combined = FALSE
  /\ owned = [i \in Ids |-> [d \in Days |-> FALSE]]
  /\ refreshed = TRUE

Add(id, name) ==
  /\ phase = "idle"
  /\ ~present[id]
  /\ ~\E other \in Ids : present[other] /\ nm[other] = name
  /\ present' = [present EXCEPT ![id] = TRUE]
  /\ nm' = [nm EXCEPT ![id] = name]
  /\ refreshed' = FALSE
  /\ UNCHANGED <<has, empty, memory, shown, phase, view, combined, owned>>

\* A row that arrived from the other phone. The sheet's duplicate-name check does not run.
ArriveCustom(id, name) ==
  /\ phase = "idle"
  /\ ~present[id]
  /\ present' = [present EXCEPT ![id] = TRUE]
  /\ nm' = [nm EXCEPT ![id] = name]
  /\ refreshed' = FALSE
  /\ UNCHANGED <<has, empty, memory, shown, phase, view, combined, owned>>

Rename(id, name) ==
  /\ phase = "idle"
  /\ present[id]
  /\ ~\E other \in Ids : other # id /\ present[other] /\ nm[other] = name
  /\ nm' = [nm EXCEPT ![id] = name]
  /\ refreshed' = FALSE
  /\ UNCHANGED <<present, has, empty, memory, shown, phase, view, combined, owned>>

Delete(id) ==
  /\ phase = "idle"
  /\ present[id]
  /\ present' = [present EXCEPT ![id] = FALSE]
  /\ has' = [has EXCEPT ![id] = [d \in Days |-> FALSE]]
  /\ empty' = [empty EXCEPT ![id] = [d \in Days |-> FALSE]]
  /\ shown' = [shown EXCEPT ![id] = [d \in Days |-> FALSE]]
  /\ owned' = [i \in Ids |-> [d \in Days |->
       i # id /\ owned[i][d] /\ (has[i][d] \/ \E k \in Ids : k # id /\ has[k][d])]]
  /\ refreshed' = FALSE
  /\ UNCHANGED <<nm, memory, phase, view, combined>>

Log(id, day) ==
  /\ phase = "idle"
  /\ present[id]
  /\ ~has[id][day]
  /\ has' = [has EXCEPT ![id][day] = TRUE]
  /\ empty' = [empty EXCEPT ![id][day] = FALSE]
  /\ owned' = [owned EXCEPT ![id][day] = TRUE]
  /\ refreshed' = FALSE
  /\ UNCHANGED <<present, nm, memory, shown, phase, view, combined>>

ArriveEmpty(id, day) ==
  /\ phase = "idle"
  /\ ~has[id][day]
  /\ has' = [has EXCEPT ![id][day] = TRUE]
  /\ empty' = [empty EXCEPT ![id][day] = TRUE]
  /\ owned' = [owned EXCEPT ![id][day] = TRUE]
  /\ refreshed' = FALSE
  /\ UNCHANGED <<present, nm, memory, shown, phase, view, combined>>

SaveKey ==
  /\ phase = "idle"
  /\ phase' = "split"
  /\ memory' = Stored(memory)
  /\ UNCHANGED <<present, nm, has, empty, shown, view, combined, owned, refreshed>>

Commit ==
  /\ phase = "split"
  /\ LET mem == memory IN
      /\ present' = NextPresent
      /\ has' = NextHas(mem)
      /\ empty' = NextEmpty(mem)
      /\ shown' = ShownFrom(mem, NextPresent)
  /\ phase' = "idle"
  /\ view' = "live"
  /\ refreshed' = TRUE
  /\ UNCHANGED <<nm, memory, combined, owned>>

Rollback ==
  /\ phase = "split"
  /\ phase' = "idle"
  /\ view' = "gap"
  /\ shown' = ShownFrom(GapMem, NextPresent)
  /\ refreshed' = TRUE
  /\ UNCHANGED <<present, nm, has, empty, memory, combined, owned>>

ImportCombined ==
  /\ phase = "idle"
  /\ present' = [i \in Ids |-> i = "a"]
  /\ nm' = [i \in Ids |-> "fog"]
  /\ has' = [i \in Ids |-> [d \in Days |-> i = "a" /\ d = 1]]
  /\ empty' = [i \in Ids |-> [d \in Days |-> FALSE]]
  /\ shown' = [i \in Ids |-> [d \in Days |-> i = "a" /\ d = 1]]
  /\ memory' = "ba"
  /\ view' = "live"
  /\ combined' = TRUE
  /\ owned' = [i \in Ids |-> [d \in Days |-> i = "a" /\ d = 1]]
  /\ refreshed' = TRUE
  /\ UNCHANGED <<phase>>

\* The orphan mark in the file is not inserted. The key is not consulted.
ImportOrphan ==
  /\ phase = "idle"
  /\ present' = [i \in Ids |-> i = "a"]
  /\ nm' = [i \in Ids |-> "fog"]
  /\ has' = [i \in Ids |-> [d \in Days |-> FALSE]]
  /\ empty' = [i \in Ids |-> [d \in Days |-> FALSE]]
  /\ shown' = [i \in Ids |-> [d \in Days |-> FALSE]]
  /\ view' = "live"
  /\ owned' = [i \in Ids |-> [d \in Days |-> FALSE]]
  /\ refreshed' = TRUE
  /\ UNCHANGED <<memory, phase, combined>>

Wipe ==
  /\ phase = "idle"
  /\ present' = [i \in Ids |-> FALSE]
  /\ has' = [i \in Ids |-> [d \in Days |-> FALSE]]
  /\ empty' = [i \in Ids |-> [d \in Days |-> FALSE]]
  /\ shown' = [i \in Ids |-> [d \in Days |-> FALSE]]
  /\ view' = "live"
  /\ owned' = [i \in Ids |-> [d \in Days |-> FALSE]]
  /\ refreshed' = TRUE
  /\ UNCHANGED <<nm, memory, phase, combined>>

Next ==
  \/ \E id \in Ids, name \in Names : Add(id, name)
  \/ \E id \in Ids, name \in Names : ArriveCustom(id, name)
  \/ \E id \in Ids, name \in Names : Rename(id, name)
  \/ \E id \in Ids : Delete(id)
  \/ \E id \in LogIds, day \in Days : Log(id, day)
  \/ \E id \in LogIds, day \in Days : ArriveEmpty(id, day)
  \/ SaveKey
  \/ Commit
  \/ Rollback
  \/ ImportCombined
  \/ ImportOrphan
  \/ Wipe

Spec == Init /\ [][Next]_vars

LateScoreKept ==
  (view = "live" /\ refreshed) =>
    \A d \in Days :
      (memory = "ba" /\ present["a"] /\ ~present["b"] /\ has["b"][d]) =>
        shown["a"][d]

NeverCombinedHides ==
  (view = "live" /\ refreshed /\ memory = "none" /\ ~combined) =>
    \A d \in Days :
      (~present["b"] /\ has["b"][d] /\ ~has["a"][d]) =>
        ~shown["a"][d] /\ ~shown["b"][d]

WinnerGoneHides ==
  (view = "live" /\ refreshed /\ ~present["a"] /\ ~present["b"]) =>
    \A i \in Ids, d \in Days : ~shown[i][d]

UniqueMarkRemains ==
  (view = "live" /\ refreshed) =>
    \A i \in Ids, d \in Days :
      (has[i][d] /\ ~empty[i][d] /\ (present[Target(i, memory, present)] \/ present[i])) =>
        shown[Target(i, memory, present)][d] \/ shown[i][d]

EmptyKeeperSafe ==
  (view = "live" /\ refreshed) =>
    \A d \in Days :
      (\E i \in Ids : owned[i][d] /\ (present[i] \/ Target(i, memory, present) # i)) =>
        \E j \in Ids : shown[j][d]

ImportRemembers ==
  combined => memory = "ba"

ScoreOnListedSymptom ==
  (view = "live" /\ refreshed) =>
    \A i \in Ids, d \in Days :
      (has[i][d] /\ ~empty[i][d] /\ present[i]) => shown[i][d]

OrphanStaysOut ==
  (view = "live" /\ refreshed /\ \A i \in Ids, d \in Days : ~has[i][d]) =>
    \A i \in Ids, d \in Days : ~shown[i][d]

====
