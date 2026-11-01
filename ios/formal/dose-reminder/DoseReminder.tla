---- MODULE DoseReminder ----
\* One slot and one medication. Reminders stay on.
\* Left out of this model: skipped, a second slot, snooze, and a follow-up id.

EXTENDS Integers, Sequences, TLC

Ids == {"a", "b"}
Nil == "nil"
Status == {"pending", "taken"}
Row == [id: Ids, status: Status]

VARIABLES rows, held, live, q, suite, glass

vars == <<rows, held, live, q, suite, glass>>

VisibleOf(log) == IF log = <<>> THEN "pending" ELSE log[Len(log)].status
Visible == VisibleOf(rows)
AttachedId == IF rows = <<>> THEN Nil ELSE rows[Len(rows)].id

\* TLC rejects equality between a string and a record, and \in STRING throws on a record.
IsIdle(h) == ToString(h) = ToString("idle")
IdOf(h) == IF IsIdle(h) THEN Nil ELSE h.id
NextOf(h) == IF IsIdle(h) THEN "taken" ELSE IF h.seen = "pending" THEN "taken" ELSE "pending"
LaneOpen == IsIdle(held) \/ IdOf(held) = Nil

Mint(log) == IF log = <<>> THEN "a" ELSE "b"

CanWrite(log, idRead) ==
  LET id == IF idRead = Nil THEN Mint(log) ELSE idRead
  IN \/ Len(log) < 2
     \/ \E i \in 1..Len(log) : log[i].id = id

WriteLog(log, idRead, next) ==
  LET id == IF idRead = Nil THEN Mint(log) ELSE idRead
  IN IF \E i \in 1..Len(log) : log[i].id = id
     THEN LET idx == CHOOSE i \in 1..Len(log) : log[i].id = id
          IN [log EXCEPT ![idx].status = next]
     ELSE Append(log, [id |-> id, status |-> next])

Enq(seq, op) ==
  LET appended == IF seq = <<>> \/ op # seq[Len(seq)] THEN Append(seq, op) ELSE seq
  IN IF Len(appended) > 2 THEN SubSeq(appended, Len(appended) - 1, Len(appended)) ELSE appended

\* Success writes whether the next log would still be listed. Failure leaves the file.
PublishResult ==
  \/ suite' = (VisibleOf(rows') = "pending")
  \/ suite' = suite

Init ==
  /\ rows = <<>>
  /\ held = "idle"
  /\ live = "none"
  /\ q = <<>>
  /\ suite = FALSE
  /\ glass = FALSE

CommitPlan ==
  /\ LaneOpen
  /\ q' = LET queued == IF live = "pending" THEN Enq(q, "R") ELSE q
          IN IF Visible = "pending" THEN Enq(queued, "A") ELSE queued
  /\ UNCHANGED <<rows, held, live, suite, glass>>

Apply ==
  /\ LaneOpen
  /\ Len(q) > 0
  /\ live' = IF Head(q) = "A" THEN "pending" ELSE "none"
  /\ q' = Tail(q)
  /\ UNCHANGED <<rows, held, suite, glass>>

\* TLC prints the action that owns the body. One shared name would hide the other tap.
NoteTake ==
  /\ LaneOpen
  /\ q' = Enq(q, "R")
  /\ UNCHANGED <<held, live, glass>>
  /\ IF Visible = "taken"
     THEN rows' = rows
     ELSE /\ CanWrite(rows, AttachedId)
          /\ rows' = WriteLog(rows, AttachedId, "taken")
  /\ PublishResult

CardTake ==
  /\ LaneOpen
  /\ q' = Enq(q, "R")
  /\ UNCHANGED <<held, live, glass>>
  /\ IF Visible = "taken"
     THEN rows' = rows
     ELSE /\ CanWrite(rows, AttachedId)
          /\ rows' = WriteLog(rows, AttachedId, "taken")
  /\ PublishResult

WidgetTake ==
  /\ LaneOpen
  /\ UNCHANGED <<held, live, glass>>
  /\ IF Visible = "pending"
     THEN /\ CanWrite(rows, AttachedId)
          /\ rows' = WriteLog(rows, AttachedId, "taken")
          /\ q' = Enq(q, "R")
     ELSE UNCHANGED <<rows, q>>
  /\ PublishResult

FreshTapRead ==
  /\ IsIdle(held)
  /\ held' = [id |-> AttachedId, seen |-> Visible]
  /\ UNCHANGED <<rows, live, q, suite, glass>>

FreshTapWrite ==
  IF IsIdle(held) THEN FALSE
  ELSE /\ CanWrite(rows, IdOf(held))
       /\ rows' = WriteLog(rows, IdOf(held), NextOf(held))
       /\ held' = "idle"
       /\ UNCHANGED <<live, q, glass>>
       /\ PublishResult

Publish ==
  /\ LaneOpen
  /\ UNCHANGED <<rows, held, live, q, glass>>
  /\ PublishResult

Reload ==
  /\ LaneOpen
  /\ glass # suite
  /\ glass' = suite
  /\ UNCHANGED <<rows, held, live, q, suite>>

Fire ==
  /\ LaneOpen
  /\ live = "pending"
  /\ live' = "none"
  /\ UNCHANGED <<rows, held, q, suite, glass>>

Done ==
  /\ LaneOpen
  /\ q = <<>>
  /\ UNCHANGED vars

Next ==
  \/ CommitPlan
  \/ Apply
  \/ NoteTake
  \/ CardTake
  \/ WidgetTake
  \/ FreshTapRead
  \/ FreshTapWrite
  \/ Publish
  \/ Reload
  \/ Fire
  \/ Done

Spec == Init /\ [][Next]_vars

\* Not a type check. Two rows, including two statuses, stay reachable.
WritersAgree ==
  /\ Len(rows) <= 1
  /\ \A i, j \in 1..Len(rows) : rows[i].status = rows[j].status

TakenNotPending == Visible = "taken" => live = "none"

WidgetHidesTaken == Visible = "taken" => glass = FALSE

====
