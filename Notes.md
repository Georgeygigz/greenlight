## Using the DSN with psql
A nice side effect of storing the DSN in an environment variable is that you can use it to easily connect to the greenlight database as the greenlight user, rather than specifying all the connection options manually when running psql. Like so:

```
psql $GREENLIGHT_DB_DSN
```
