const TOKEN_KEY = 'slova_admin_token';

export function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}
export function setToken(t: string | null) {
  if (t) localStorage.setItem(TOKEN_KEY, t);
  else localStorage.removeItem(TOKEN_KEY);
}

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
  }
}

export async function api<T = any>(method: string, path: string, body?: unknown): Promise<T> {
  const token = getToken();
  const res = await fetch(`/api${path}`, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await res.json().catch(() => null);
  if (!res.ok) {
    if (res.status === 401) {
      setToken(null);
      window.dispatchEvent(new Event('slova-logout'));
    }
    throw new ApiError(data?.message || `Greška ${res.status}`, res.status);
  }
  return data as T;
}

export const fmtDate = (s?: string | null) => (s ? new Date(s).toLocaleString('sr-RS') : '—');
