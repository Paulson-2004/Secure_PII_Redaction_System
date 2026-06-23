import mysql.connector
from mysql.connector import Error
from config import Config


class Database:
    """Database connection and query handler"""
    
    def __init__(self, config=None):
        self.config = config or Config
        self.connection = None
    
    def connect(self):
        """Establish database connection"""
        def _cfg(key, default=None):
            if isinstance(self.config, dict):
                return self.config.get(key, default)
            return getattr(self.config, key, default)

        try:
            self.connection = mysql.connector.connect(
                host=_cfg('MYSQL_HOST', '127.0.0.1'),
                user=_cfg('MYSQL_USER', 'root'),
                password=_cfg('MYSQL_PASSWORD', ''),
                database=_cfg('MYSQL_DB', 'privlock'),
            )
            if self.connection.is_connected():
                print("Database connection successful")
                return True
        except Error as e:
            print(f"Error while connecting to MySQL: {e}")
            return False
    
    def disconnect(self):
        """Close database connection"""
        if self.connection and self.connection.is_connected():
            self.connection.close()
            print("Database connection closed")
    
    def query(self, sql, params=None):
        """Execute a query and return results"""
        if not self.connection or not self.connection.is_connected():
            if not self.connect():
                return None
        
        cursor = self.connection.cursor(dictionary=True)
        try:
            cursor.execute(sql, params or ())
            result = cursor.fetchall()
            cursor.close()
            return result
        except Error as e:
            print(f"Database query error: {e}")
            cursor.close()
            return None
    
    def execute(self, sql, params=None):
        """Execute an INSERT, UPDATE, or DELETE query"""
        if not self.connection or not self.connection.is_connected():
            if not self.connect():
                return None
        
        cursor = self.connection.cursor()
        try:
            cursor.execute(sql, params or ())
            self.connection.commit()
            affected_rows = cursor.rowcount
            last_id = cursor.lastrowid
            cursor.close()
            return {'affected': affected_rows, 'last_id': last_id}
        except Error as e:
            self.connection.rollback()
            print(f"Database execution error: {e}")
            cursor.close()
            return None
    
    def query_one(self, sql, params=None):
        """Execute a query and return only the first result"""
        result = self.query(sql, params)
        return result[0] if result else None


# Global database instance
db = Database()
