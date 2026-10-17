import { NextResponse, type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/proxy";

const guestOnlyPaths = ["/masuk", "/daftar"];

function redirectTo(request: NextRequest, pathname: string, source: NextResponse) {
  const redirectResponse = NextResponse.redirect(new URL(pathname, request.url));
  // Bawa cookie sesi yang baru disegarkan.
  source.cookies.getAll().forEach((cookie) => redirectResponse.cookies.set(cookie));
  return redirectResponse;
}

export async function proxy(request: NextRequest) {
  const { response, user } = await updateSession(request);
  const isGuestOnlyPath = guestOnlyPaths.includes(request.nextUrl.pathname);

  if (!user && !isGuestOnlyPath) {
    return redirectTo(request, "/masuk", response);
  }
  if (user && isGuestOnlyPath) {
    return redirectTo(request, "/", response);
  }
  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)",
  ],
};
