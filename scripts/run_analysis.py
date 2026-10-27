import argparse
import sqlite3
import sys
from pathlib import Path
from tabulate import tabulate

def run_analysis(sql_file_path: Path, db_path: Path):
    if not sql_file_path.exists():
        print(f"Error: SQL file not found: {sql_file_path}")
        sys.exit(1)
        
    if not db_path.exists():
        print(f"Error: Database not found at {db_path}")
        sys.exit(1)

    with open(sql_file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Simple logic to split statements and associate comments
    statements = []
    current_comment = None
    for block in content.split(';'):
        block = block.strip()
        if not block:
            continue
            
        lines = block.split('\n')
        sql_lines = []
        for line in lines:
            line_strip = line.strip()
            if line_strip.startswith('--'):
                if current_comment is None:
                    current_comment = line_strip[2:].strip()
                else:
                    current_comment += " " + line_strip[2:].strip()
            else:
                sql_lines.append(line)
        
        sql = '\n'.join(sql_lines).strip()
        if sql:
            statements.append({'comment': current_comment, 'sql': sql})
            current_comment = None

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    for idx, stmt in enumerate(statements, 1):
        header = stmt['comment'] if stmt['comment'] else f"Query {idx}"
        print(f"\n{'='*80}\n{header}\n{'='*80}")
        
        try:
            cursor.execute(stmt['sql'])
            columns = [description[0] for description in cursor.description] if cursor.description else []
            rows = cursor.fetchall()
            
            if columns:
                print(tabulate(rows, headers=columns, tablefmt="psql"))
                print(f"({len(rows)} rows returned)\n")
            else:
                print("Query executed successfully (no rows returned).\n")
                
        except sqlite3.Error as e:
            print(f"Error executing query: {e}")
            print(f"SQL:\n{stmt['sql']}\n")

    conn.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run SQL analysis scripts against Olist database")
    parser.add_argument("sql_file", type=str, help="Path to SQL file")
    parser.add_argument("--db-path", type=str, default="olist.db", help="Path to SQLite database")
    
    args = parser.parse_args()
    run_analysis(Path(args.sql_file), Path(args.db_path))
