export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string) { super(message); }
}
export const bad = (code: string, message: string) => new ApiError(400, code, message);
export const unauthorized = (message = 'Inicia sesión para continuar') => new ApiError(401, 'unauthorized', message);
export const forbidden = (message = 'No tienes permiso para esta acción') => new ApiError(403, 'forbidden', message);
export const notFound = (message = 'No encontrado') => new ApiError(404, 'not_found', message);
export const conflict = (code: string, message: string) => new ApiError(409, code, message);
