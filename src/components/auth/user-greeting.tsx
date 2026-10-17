import { connection } from "next/server";
import { Button } from "@/components/ui/button";
import { signOut } from "@/lib/auth/actions";
import { createSupabaseServerClient } from "@/lib/supabase/server";

// Membaca cookie sesi saat request, jadi harus dibungkus <Suspense> oleh pemakainya.
export async function UserGreeting() {
  await connection();
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: profile } = user
    ? await supabase
        .from("users")
        .select("full_name, role")
        .eq("id", user.id)
        .single()
    : { data: null };

  return (
    <>
      <h1 className="text-2xl font-semibold">
        Halo, {profile?.full_name ?? "Pengguna"}
      </h1>
      <p className="text-muted-foreground">Peran: {profile?.role ?? "-"}</p>
      <form action={signOut}>
        <Button type="submit" variant="outline">
          Keluar
        </Button>
      </form>
    </>
  );
}
