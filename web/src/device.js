// Fotos, ubicación, cola sin conexión y notificaciones del sistema.
import { idbOp } from './data/stores.js';

/**
 * Comprime una imagen a JPEG (máx. 1280 px) dibujándola en un canvas.
 * Al re-codificarse se descartan los metadatos EXIF (incluida la ubicación GPS
 * de la cámara), igual que en la app Flutter.
 */
export async function compressImage(file, { maxSide = 1280, maxChars = 190000 } = {}) {
  const bmp = await loadBitmap(file);
  let side = maxSide;
  let quality = 0.74;
  for (let i = 0; i < 6; i++) {
    const scale = Math.min(1, side / Math.max(bmp.width, bmp.height));
    const canvas = document.createElement('canvas');
    canvas.width = Math.round(bmp.width * scale);
    canvas.height = Math.round(bmp.height * scale);
    canvas.getContext('2d').drawImage(bmp, 0, 0, canvas.width, canvas.height);
    const url = canvas.toDataURL('image/jpeg', quality);
    if (url.length <= maxChars) return url;
    side = Math.round(side * 0.82);
    quality = Math.max(0.5, quality - 0.06);
  }
  throw new Error('No se pudo reducir la fotografía. Intenta con otra imagen.');
}
function loadBitmap(file) {
  if (globalThis.createImageBitmap) {
    return createImageBitmap(file, { imageOrientation: 'from-image' }).catch(() => loadImg(file));
  }
  return loadImg(file);
}
function loadImg(file) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('El archivo no es una imagen válida.'));
    img.src = URL.createObjectURL(file);
  });
}

/** Ubicación GPS con mensajes en español. */
export function locate() {
  return new Promise((resolve) => {
    if (!navigator.geolocation) return resolve({ error: 'Este navegador no ofrece ubicación. Ubica el punto en el mapa.' });
    navigator.geolocation.getCurrentPosition(
      (p) => resolve({ lat: p.coords.latitude, lng: p.coords.longitude, accuracy: p.coords.accuracy }),
      (e) => resolve({
        error: e.code === 1
          ? 'Permiso de ubicación denegado. Ubica el punto tocando el mapa.'
          : 'No se pudo obtener la ubicación. Ubica el punto tocando el mapa.',
      }),
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 60000 },
    );
  });
}

// ------------------------------------------------------------ cola offline
const memQueue = new Map();
export const queue = {
  async add(draft) {
    try { await idbOp('queue', 'readwrite', (s) => s.put(draft, draft.client_uuid)); } catch { memQueue.set(draft.client_uuid, draft); }
  },
  async all() {
    try { return [...(await idbOp('queue', 'readonly', (s) => s.getAll())), ...memQueue.values()]; } catch { return [...memQueue.values()]; }
  },
  async remove(id) {
    memQueue.delete(id);
    try { await idbOp('queue', 'readwrite', (s) => s.delete(id)); } catch {}
  },
};

export function isNetworkError(e) {
  return e instanceof TypeError || /failed to fetch|network|load failed/i.test(String(e?.message || e));
}

// ------------------------------------------------------------ notificaciones
export async function systemNotify(title, body) {
  try {
    if (!('Notification' in window) || Notification.permission !== 'granted') return;
    const reg = await navigator.serviceWorker?.getRegistration?.();
    if (reg) await reg.showNotification(title, { body, icon: 'icons/icon-192.png', badge: 'icons/icon-192.png', lang: 'es' });
    else new Notification(title, { body });
  } catch { /* el entorno no permite notificaciones */ }
}
