# Portability note — structured-data-duckdb

This skill was migrated unchanged from the `pi-workspace` monorepo.

Its instructions currently name Pi runtime extensions:

- `pi-office` (`@mammothb/pi-office`) to inspect XLSX workbooks;
- `pi-alchemy` (`@nqbao/pi-alchemy`) and its tools `alchemy_query`,
  `alchemy_schema`, `alchemy_tables`, `alchemy_load` to run DuckDB.

The method itself (inspect → `DESCRIBE read_xlsx(...)` → `CREATE TABLE` →
verify schema → sample → SQL) is harness-neutral.

## Status

| Harness | Status |
|---|---|
| Pi | Works as written when the two extensions are installed. |
| Hermes | **Adaptation to do.** Map the steps to an available DuckDB capability (DuckDB CLI or Python `duckdb` package through the terminal tool, or an MCP server) and to a spreadsheet inspection capability. |

## Next step (not done in V1)

Split the skill into a portable body (method + SQL) and short per-harness
"runtime adapter" sections, without duplicating the skill.
