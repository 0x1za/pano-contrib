// Queue a contribution on the phone, push the queue when online, keep
// what the server rejected with its reason so the person can see why.
// Wire vocabulary must stay in lockstep with app/services/sync_applier.rb.
import { Outbox } from "sync/outbox"

const POLL_MS = 30000

export class SyncClient {
  constructor() {
    this.outbox = new Outbox()
    this.entries = []
    this.listeners = new Set()
    this.syncing = false
  }

  async boot() {
    await this.outbox.init()
    this.entries = await this.outbox.all()
    this.onlineHandler = () => this.sync()
    addEventListener("online", this.onlineHandler)
    this.pollTimer = setInterval(() => this.sync(), POLL_MS)
    this.notify()
    this.sync()
    return this
  }

  teardown() {
    if (this.onlineHandler) removeEventListener("online", this.onlineHandler)
    if (this.pollTimer) clearInterval(this.pollTimer)
  }

  subscribe(fn) {
    this.listeners.add(fn)
    fn(this.entries)
    return () => this.listeners.delete(fn)
  }

  notify() {
    this.listeners.forEach((fn) => fn(this.entries))
  }

  get pending() { return this.entries.filter((e) => !e.rejected) }

  // args: { kind, address, note?, sub?, reason? }
  async queue(args) {
    const entry = { mutationId: crypto.randomUUID(), queuedAt: Date.now(), mutation: { type: "contribute", args } }
    entry.mutation.mutationId = entry.mutationId
    this.entries.push(entry)
    await this.outbox.put(entry)
    this.notify()
    this.sync()
    return entry
  }

  async forget(mutationId) {
    this.entries = this.entries.filter((e) => e.mutationId !== mutationId)
    await this.outbox.remove([mutationId])
    this.notify()
  }

  async sync() {
    if (!navigator.onLine || this.syncing) return
    const batch = this.pending
    if (!batch.length) return
    this.syncing = true
    try {
      const res = await fetch("/sync/push", {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({ mutations: batch.map((e) => e.mutation) })
      })
      if (!res.ok) throw new Error(`push ${res.status}`)
      const { results } = await res.json()
      const done = results.filter((r) => r.status === "accepted" || r.status === "duplicate").map((r) => r.mutationId)
      for (const r of results.filter((r) => r.status === "rejected")) {
        const entry = this.entries.find((e) => e.mutationId === r.mutationId)
        if (entry) { entry.rejected = r.reason || "rejected"; await this.outbox.put(entry) }
      }
      if (done.length) {
        this.entries = this.entries.filter((e) => !done.includes(e.mutationId))
        await this.outbox.remove(done)
      }
      this.lastSyncedAt = Date.now()
      this.notify()
    } catch (error) {
      console.warn("pano sync failed; will retry", error)
    } finally {
      this.syncing = false
    }
  }
}

// One client per page; controllers share it.
let shared = null
export function syncClient() {
  if (!shared) { shared = new SyncClient(); shared.ready = shared.boot() }
  return shared
}
