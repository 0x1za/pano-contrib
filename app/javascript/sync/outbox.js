// The outbox: contributions made offline, kept in IndexedDB until the
// server has answered for each. Mirrors span's sync/store.js in shape.
const DB_NAME = "pano"
const DB_VERSION = 1

function open() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION)
    req.onupgradeneeded = () => {
      const db = req.result
      if (!db.objectStoreNames.contains("outbox")) db.createObjectStore("outbox", { keyPath: "mutationId" })
    }
    req.onsuccess = () => resolve(req.result)
    req.onerror = () => reject(req.error)
  })
}

function reqP(request) {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
}

export class Outbox {
  async init() {
    this.db = await open()
    return this
  }

  store(mode = "readonly") {
    return this.db.transaction("outbox", mode).objectStore("outbox")
  }

  async all() {
    const all = await reqP(this.store().getAll())
    return all.sort((a, b) => a.queuedAt - b.queuedAt)
  }

  async put(entry) {
    return reqP(this.store("readwrite").put(entry))
  }

  async remove(mutationIds) {
    const tx = this.db.transaction("outbox", "readwrite")
    const os = tx.objectStore("outbox")
    mutationIds.forEach((id) => os.delete(id))
    return new Promise((resolve, reject) => {
      tx.oncomplete = () => resolve()
      tx.onerror = () => reject(tx.error)
    })
  }
}
