"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import {
  signInSchema,
  signUpSchema,
  type AuthFormState,
} from "@/lib/auth/schemas";

function readText(formData: FormData, fieldName: string) {
  const value = formData.get(fieldName);
  return typeof value === "string" ? value : "";
}

export async function signIn(
  _previousState: AuthFormState,
  formData: FormData,
): Promise<AuthFormState> {
  const email = readText(formData, "email");
  const parsed = signInSchema.safeParse({
    email,
    password: readText(formData, "password"),
  });

  if (!parsed.success) {
    return {
      fieldErrors: z.flattenError(parsed.error).fieldErrors,
      values: { email },
    };
  }

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.signInWithPassword(parsed.data);

  if (error) {
    return { message: "Email atau kata sandi salah.", values: { email } };
  }

  redirect("/");
}

export async function signUp(
  _previousState: AuthFormState,
  formData: FormData,
): Promise<AuthFormState> {
  const fullName = readText(formData, "fullName");
  const email = readText(formData, "email");
  const parsed = signUpSchema.safeParse({
    fullName,
    email,
    password: readText(formData, "password"),
  });

  if (!parsed.success) {
    return {
      fieldErrors: z.flattenError(parsed.error).fieldErrors,
      values: { fullName, email },
    };
  }

  const supabase = await createSupabaseServerClient();
  // Hanya full_name yang dikirim sebagai metadata. Peran ditentukan trigger di database.
  const { data, error } = await supabase.auth.signUp({
    email: parsed.data.email,
    password: parsed.data.password,
    options: { data: { full_name: parsed.data.fullName } },
  });

  if (error) {
    return {
      message: "Pendaftaran gagal. Periksa data Anda atau coba email lain.",
      values: { fullName, email },
    };
  }

  if (!data.session) {
    return {
      message: "Pendaftaran berhasil. Silakan masuk.",
      values: { email },
    };
  }

  redirect("/");
}

export async function signOut() {
  const supabase = await createSupabaseServerClient();
  await supabase.auth.signOut();
  redirect("/masuk");
}
