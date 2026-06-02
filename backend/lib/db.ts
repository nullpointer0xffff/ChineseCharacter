import postgres from "postgres";

const connectionString = process.env.POSTGRES_URL;

if (!connectionString) {
  throw new Error("POSTGRES_URL is not configured.");
}

export const sql = postgres(connectionString, {
  ssl: "require",
  max: 5
});
