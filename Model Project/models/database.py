import mysql.connector
from flask import g

def get_db():
    if 'db' not in g:
        g.db = mysql.connector.connect(
            host="localhost",
            user="root",
            password="",
            database="diabetes_app"
        )
    return g.db

def get_cursor():
    db = get_db()
    return db.cursor(dictionary=True)

def close_db(e=None):
    db = g.pop('db', None)
    if db is not None:
        db.close()