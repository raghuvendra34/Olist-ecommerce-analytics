import argparse
import csv
import logging
import sqlite3
import pandas as pd
from pathlib import Path

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

TABLE_MAPPING = {
    'olist_customers_dataset.csv': 'customers',
    'olist_orders_dataset.csv': 'orders',
    'olist_order_items_dataset.csv': 'order_items',
    'olist_order_payments_dataset.csv': 'order_payments',
    'olist_order_reviews_dataset.csv': 'order_reviews',
    'olist_products_dataset.csv': 'products',
    'olist_sellers_dataset.csv': 'sellers',
    'olist_geolocation_dataset.csv': 'geolocation',
    'product_category_name_translation.csv': 'product_category_name_translation'
}

def load_data(data_dir: Path, db_path: Path, schema_path: Path):
    if not data_dir.exists():
        logger.error(f"Data directory not found: {data_dir}")
        return
    
    if not schema_path.exists():
        logger.error(f"Schema file not found: {schema_path}")
        return

    logger.info(f"Connecting to database at {db_path}")
    conn = sqlite3.connect(db_path)
    
    logger.info(f"Executing schema from {schema_path}")
    with open(schema_path, 'r', encoding='utf-8') as f:
        conn.executescript(f.read())
        
    for filename, table_name in TABLE_MAPPING.items():
        file_path = data_dir / filename
        if not file_path.exists():
            logger.warning(f"File not found: {file_path}, skipping table {table_name}")
            continue
            
        logger.info(f"Loading {filename} into {table_name}...")
        try:
            kwargs = {
                'encoding': 'utf-8',
                'encoding_errors': 'replace'
            }
            if 'reviews' in filename:
                kwargs['quoting'] = csv.QUOTE_ALL
                
            df = pd.read_csv(file_path, **kwargs)
            df.to_sql(table_name, conn, if_exists='append', index=False)
            logger.info(f"Successfully loaded {len(df)} rows into {table_name}")
        except Exception as e:
            logger.error(f"Error loading {filename} into {table_name}: {e}")
            
    conn.commit()
    conn.close()
    logger.info("Data loading complete.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Load Olist data into SQLite database")
    parser.add_argument("--data-dir", type=str, default="data/", help="Path to data directory")
    parser.add_argument("--db-path", type=str, default="olist.db", help="Path to SQLite database")
    parser.add_argument("--schema", type=str, default="sql/schema.sql", help="Path to schema SQL file")
    
    args = parser.parse_args()
    
    load_data(Path(args.data_dir), Path(args.db_path), Path(args.schema))
