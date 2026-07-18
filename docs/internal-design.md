# Internal Design Guide

WaylandClientKit has to be careful about thread ownership, callback ordering,
and destruction. That work is easier to maintain when each fact has one clear
home. Use these guidelines when adding or reviewing internal code.

## Store each fact once

A resource's lifetime belongs to one record or owner. Other dictionaries may
index that record by a seat, surface, or raw handle, but they shouldn't carry a
second copy of its mutable lifetime.

Keep insertion and removal of secondary indexes in one place. Tests should check
that every index resolves to the same record and that terminal removal clears
all indexes.

## Derive simple state

Don't store a flag when it is a direct result of other private fields. For
example, content is dirty when its content generation is newer than its
presented generation.

An explicit enum is still useful when it prevents an important invalid state.
Prefer a small checked invariant when an enum would force every transition to
copy the same unrelated values between cases.

## Use reducers when they add a real boundary

A reducer and effect plan are useful when the state transition can be tested on
its own and fallible resource work happens before a nonthrowing commit. If effect
handling can mutate another store, publish events, or throw before the planned
state is installed, the split does not provide an atomic transition.

For owner-thread-only domains, one mutable store is often clearer. Keep pure
transition helpers for protocol rules that benefit from direct tests.

## Give every owner type a job

A coordinator or helper object should own state, ordering, policy, or a useful
test boundary. A type that only forwards every call to another value should
usually be a method or an extension instead.

## Generate code that follows a schema

Interface names, request and event arguments, versions, nullability, opcodes,
and destructors come from Wayland XML. Generate code whose differences are
limited to those facts. Keep client choices in a small checked policy file and
keep semantic projections, ownership rules, and error policy in handwritten
Swift.

Generated files stay checked in so changes can be reviewed. Generation should
be deterministic, and the normal repository checks should fail when committed
output is stale.

## Keep linear ownership local

Use noncopyable values for local, exactly-once work such as prepared reads,
owned descriptors, prepared transactions, and buffer leases. Compositor-owned
objects with aliases and callbacks still need runtime lifetime checks.

## Explain unsafe boundaries

Every unsafe wrapper or unchecked sendable type should make these points clear
in nearby documentation or the strict memory-safety audit:

- What owns the underlying object.
- Which thread or executor may access it.
- What transfers ownership.
- What keeps a pointer or descriptor valid.
- What invalidates it.
- Whether destruction is exactly once, at most once, or best effort.
- What deinitialization does when normal cleanup was missed.

## Resume work after unlocking

Never resume a continuation or call user-provided work while holding an internal
lock. First update the protected state and collect the work to resume. Unlock,
then deliver it.

## Share behavior, not just names

Two protocol paths should share an implementation when their lifetime and
transition rules are the same. Similar type names or matching `destroy` methods
aren't enough. Keep distinct types when they carry different ownership or API
meaning.
