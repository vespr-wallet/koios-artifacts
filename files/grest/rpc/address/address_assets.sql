CREATE OR REPLACE FUNCTION grest.address_assets (_addresses text[])
  RETURNS TABLE (
    address varchar,
    asset_list jsonb
  )
  LANGUAGE PLPGSQL
  AS $$
BEGIN
  RETURN QUERY

  WITH _all_assets AS (
    SELECT
      txo.address,
      ma.policy,
      ma.name,
      ma.fingerprint,
      COALESCE(aic.decimals, 0) as decimals,
      SUM(mtx.quantity) as quantity
    FROM
      MA_TX_OUT MTX
      INNER JOIN MULTI_ASSET MA ON MA.id = MTX.ident
      LEFT JOIN grest.asset_info_cache aic ON aic.asset_id = MA.id
      INNER JOIN TX_OUT TXO ON TXO.ID = MTX.TX_OUT_ID
      LEFT JOIN TX_IN ON TXO.TX_ID = TX_IN.TX_OUT_ID
        AND TXO.INDEX::smallint = TX_IN.TX_OUT_INDEX::smallint
    WHERE
      TXO.address = ANY(_addresses)
      AND TX_IN.tx_out_id IS NULL
    GROUP BY
      TXO.address, MA.policy, MA.name, ma.fingerprint, aic.decimals
  )

  SELECT
    assets_grouped.address,
    assets_grouped.asset_list
  FROM (
    SELECT
      aa.address,
      JSONB_AGG(
        JSONB_BUILD_OBJECT(
          'policy_id', ENCODE(aa.policy, 'hex'),
          'asset_name', ENCODE(aa.name, 'hex'),
          'fingerprint', aa.fingerprint,
          'decimals', aa.decimals,
          'quantity', aa.quantity::text
        )
      ) as asset_list
    FROM 
      _all_assets aa
    GROUP BY
      aa.address
  ) assets_grouped;
END;
$$;

COMMENT ON FUNCTION grest.address_assets IS 'Get the list of all the assets (policy, name and quantity) for given addresses';

