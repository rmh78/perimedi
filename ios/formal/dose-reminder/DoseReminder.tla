---- MODULE DoseReminder ----
\* One slot and one medication. Reminders stay on and notifications stay allowed.
\* There is no clock. live is the dose id, a follow-up id, or the snooze id.
\* The queue keeps the last two ops, so an older add can fall off.

EXTENDS Integers, Sequences

Status == {"pending", "taken"}

VARIABLES status, live, q, snap, suite, glass

vars == <<status, live, q, snap, suite, glass>>

Enq(seq, op) ==
  LET appended == IF seq = <<>> \/ op # seq[Len(seq)] THEN Append(seq, op) ELSE seq
  IN IF Len(appended) > 2 THEN SubSeq(appended, Len(appended) - 1, Len(appended)) ELSE appended

\* Success writes whether this slot would still be listed. Failure leaves the file.
PublishResult ==
  \/ suite' = (status' = "pending")
  \/ suite' = suite

Init ==
  /\ status = "pending"
  /\ live = "none"
  /\ q = <<>>
  /\ snap = "idle"
  /\ suite = FALSE
  /\ glass = FALSE

ReadSnap ==
  /\ snap = "idle"
  /\ snap' = IF live = "pending" THEN "saw" ELSE "miss"
  /\ UNCHANGED <<status, live, q, suite, glass>>

CommitPlan ==
  /\ snap # "idle"
  /\ q' = LET queued == IF snap = "saw" THEN Enq(q, "R") ELSE q
          IN IF status = "pending" THEN Enq(queued, "A") ELSE queued
  /\ snap' = "idle"
  /\ UNCHANGED <<status, live, suite, glass>>

Apply ==
  /\ Len(q) > 0
  /\ live' = IF Head(q) = "A" THEN "pending" ELSE "none"
  /\ q' = Tail(q)
  /\ UNCHANGED <<status, snap, suite, glass>>

\* TLC names the operator that owns the body. An alias would collapse these taps.
\* The cancel is queued and returns before the center runs it.
NoteTake ==
  /\ q' = Enq(q, "R")
  /\ status' = "taken"
  /\ UNCHANGED <<live, snap, glass>>
  /\ PublishResult

CardTake ==
  /\ q' = Enq(q, "R")
  /\ status' = "taken"
  /\ UNCHANGED <<live, snap, glass>>
  /\ PublishResult

WidgetTake ==
  /\ q' = IF status = "pending" THEN Enq(q, "R") ELSE q
  /\ status' = "taken"
  /\ UNCHANGED <<live, snap, glass>>
  /\ PublishResult

FreshTap ==
  /\ status' = IF status = "pending" THEN "taken" ELSE "pending"
  /\ UNCHANGED <<q, live, snap, glass>>
  /\ PublishResult

Publish ==
  /\ UNCHANGED <<status, live, q, snap, glass>>
  /\ PublishResult

Reload ==
  /\ glass # suite
  /\ glass' = suite
  /\ UNCHANGED <<status, live, q, snap, suite>>

Fire ==
  /\ live = "pending"
  /\ live' = "none"
  /\ UNCHANGED <<status, q, snap, suite, glass>>

Done ==
  /\ q = <<>>
  /\ snap = "idle"
  /\ UNCHANGED vars

Next ==
  \/ ReadSnap
  \/ CommitPlan
  \/ Apply
  \/ NoteTake
  \/ CardTake
  \/ WidgetTake
  \/ FreshTap
  \/ Publish
  \/ Reload
  \/ Fire
  \/ Done

Spec == Init /\ [][Next]_vars

WritersAgree == status \in Status

TakenNotPending == status = "taken" => live = "none"

WidgetHidesTaken == status = "taken" => glass = FALSE

====
