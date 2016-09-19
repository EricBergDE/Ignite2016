Import-Module RemoteDesktop

$RDCB = "IgniteRDS01.ignite.demo"
$RDSH01 = "IgniteRDS02.ignite.demo"
$RDSH02 = "IgniteRDS03.ignite.demo"
$user1 = "ignite\eric.berg"
$user2 = "ignite\markus.klein"
$Collection = "IgnitePersonalDesktopSH"


# Get deployed Session collection

Get-RDSessionCollection -ConnectionBroker $RDCB

# Remove deployed collection

Remove-RDSessionCollection -CollectionName "IgniteCollection"

# Deploy Personal Session Collection

New-RDSessionCollection -CollectionName $Collection -ConnectionBroker $RDCB -SessionHost $RDSH01,$RDSH02 -PersonalUnmanaged -GrantAdministrativePrivilege

# Assign User and Desktop

Set-RDPersonalSessionDesktopAssignment -CollectionName $Collection -ConnectionBroker $RDCB -User $user1 -Name $RDSH01
Set-RDPersonalSessionDesktopAssignment -CollectionName $Collection -ConnectionBroker $RDCB -User $user2 -Name $RDSH02

# Get Assignment

Get-RDPersonalSessionDesktopAssignment -CollectionName $Collection -ConnectionBroker $RDCB

# Remove Assignment

Remove-RDPersonalSessionDesktopAssignment -CollectionName $Collection -ConnectionBroker $RDCB -User "ignite\eric.berg"
Remove-RDPersonalSessionDesktopAssignment -CollectionName $Collection -ConnectionBroker $RDCB -User "ignite\markus.klein"

# Remove deployed collection

Remove-RDSessionCollection -CollectionName $Collection

# Deploy Personal Session Collection AutoAssign

New-RDSessionCollection -CollectionName $Collection -ConnectionBroker $RDCB -SessionHost $RDSH01,$RDSH02 -PersonalUnmanaged -AutoAssignUser -GrantAdministrativePrivilege