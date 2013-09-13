@startuml
title Submitting source state updates
autonumber
participant Perforce
participant Backup
participant Developer
participant Exchange
participant Reviewer
== Import from P4 ==
[->> Perforce : submit something
activate Developer
Developer <- Perforce : get latest revision
Developer -> Developer : commit on local master
Developer -> Exchange : push master, pull an push if diverged
deactivate Developer

== update master ==
[->> Developer : notify master changed
activate Developer
Developer <- Exchange : fetch commits
Developer -> Developer : rebase topic branches
Developer -> Backup : mirror
deactivate Developer

== Submit changes - no review ==
Developer -> Developer : create topic branch
activate Developer
Developer -> Developer : commit on topic branch
Developer -> Backup : mirror
Developer -> Developer : merge to local master
Developer -> Exchange : push master
deactivate Developer

== Submit changes - with review ==
Developer -> Developer : create topic branch
activate Developer
Developer -> Developer : commit on topic branch
Developer -> Backup : mirror
Developer -> Developer : create review branch
Developer -> Exchange : push review branch
Developer ->> Reviewer : notify
deactivate Developer
activate Reviewer
Reviewer <- Exchange : fetch commits from developer
Reviewer -> Reviewer : commit on review branch
Reviewer -> Exchange : push review branch
Reviewer ->> Developer : notify
deactivate Reviewer
activate Developer
Developer <- Exchange : fetch commits from reviewer
Developer -> Developer : merge to local master
Developer -> Exchange : push master
deactivate Developer

@enduml